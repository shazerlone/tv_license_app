import { BadRequestException, Injectable, NotFoundException, UnauthorizedException, Logger } from '@nestjs/common';
import { Deposit, DepositStatus, KycStatus, LedgerType, Prisma } from '@prisma/client';
import { randomBytes, createHmac, timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { SettingsService } from '../settings/settings.service';
import { genId } from '../common/ids';
import { CreateDepositDto, DepositDto, DepositMethodDto, DepositAddressDto } from './dto/deposit.dto';
import { CryptoDepositService } from './crypto/crypto-deposit.service';
import { CryptoAddressService } from './crypto/crypto-address.service';
import { ChainDeposit, DepositNetwork } from './crypto/address-provider';
import { NotificationsService } from '../notifications/notifications.service';

// Hard production safety gate: auto-crediting a deposit without real on-chain
// confirmation is a DEV-ONLY convenience. It is OFF unless DEPOSIT_AUTO_CONFIRM
// is explicitly "true", regardless of the admin PlatformSettings toggle — so a
// misconfigured setting can never mint real balance in production.
const DEPOSIT_AUTO_CONFIRM = process.env.DEPOSIT_AUTO_CONFIRM === 'true';
// Optional generic webhook secret for a custom processor (used only when no
// first-class provider is configured). First-class providers (NOWPayments, …)
// bring their own signature scheme via CryptoDepositService.
const CRYPTO_WEBHOOK_SECRET = process.env.CRYPTO_WEBHOOK_SECRET ?? '';

/**
 * Deposits into the Millimore wallet. Method availability, the minimum amount,
 * and auto-confirm all come from admin-editable PlatformSettings. In test mode
 * deposits confirm and credit the wallet immediately; in production a crypto
 * webhook (or admin approval) calls `confirm()` exactly once when funds arrive.
 */
@Injectable()
export class DepositsService {
  private readonly logger = new Logger('DepositsService');

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallet: WalletService,
    private readonly settings: SettingsService,
    private readonly crypto: CryptoDepositService,
    private readonly addresses: CryptoAddressService,
    private readonly notifications: NotificationsService,
  ) {
    this.logger.log(
      DEPOSIT_AUTO_CONFIRM
        ? '⚠️  Deposits: AUTO-CONFIRM ON (dev only — wallet credited without on-chain payment)'
        : `Deposits: auto-confirm OFF — credited only by ${this.crypto.enabled ? `${this.crypto.name} webhook` : 'webhook/admin'}`,
    );
  }

  /** Distinct methods the user has actually funded from (confirmed deposits).
   *  Drives the AML same-source withdrawal rule. */
  async fundedMethods(userId: string): Promise<string[]> {
    const rows = await this.prisma.deposit.findMany({
      where: { userId, status: DepositStatus.confirmed },
      select: { method: true },
      distinct: ['method'],
    });
    return rows.map((r) => r.method);
  }

  async methods(): Promise<DepositMethodDto[]> {
    const s = await this.settings.get();
    return [
      { id: 'crypto', label: 'Crypto (USDT / BTC)', active: s.cryptoEnabled, comingSoon: !s.cryptoEnabled, assets: ['USDT', 'BTC', 'ETH'] },
      { id: 'metatrader', label: 'MetaTrader transfer', active: false, comingSoon: true },
      { id: 'card', label: 'Debit / Credit card', active: s.cardEnabled, comingSoon: !s.cardEnabled },
      { id: 'bank', label: 'Bank transfer', active: s.bankEnabled, comingSoon: !s.bankEnabled },
    ];
  }

  private toDto(d: Deposit): DepositDto {
    return {
      id: d.id,
      amount: d.amount,
      currency: d.currency,
      method: d.method,
      asset: d.asset,
      address: d.address,
      payAmount: d.payAmount ?? null,
      payCurrency: d.payCurrency ?? null,
      status: d.status,
      createdAt: d.createdAt.toISOString(),
      confirmedAt: d.confirmedAt?.toISOString() ?? null,
    };
  }

  /** A placeholder deposit address — DEV ONLY (never handed out in production). */
  private mockAddress(asset: string): string {
    const prefix = asset === 'BTC' ? 'bc1' : '0x';
    return `${prefix}${randomBytes(18).toString('hex')}`;
  }

  /**
   * Issue a deposit payment for `depositId`. In production this comes from the
   * configured crypto processor (real pay-to address + exact amount); we NEVER
   * hand out a fake address there. Dev/test (DEPOSIT_AUTO_CONFIRM=true) uses a
   * mock; with neither, deposits fail closed.
   */
  private async issuePayment(
    depositId: string,
    amountUsd: number,
    asset: string,
  ): Promise<{ address: string; payAmount?: number; payCurrency?: string; providerRef?: string }> {
    if (this.crypto.enabled) {
      try {
        return await this.crypto.createPayment(depositId, amountUsd, asset);
      } catch (err) {
        this.logger.warn(`crypto provider (${this.crypto.name}) createPayment failed: ${String(err)}`);
        throw new BadRequestException({
          code: 'deposits_unavailable',
          message: 'Couldn’t start the deposit right now. Please try again shortly.',
        });
      }
    }
    if (DEPOSIT_AUTO_CONFIRM) return { address: this.mockAddress(asset) }; // dev/test only
    throw new BadRequestException({
      code: 'deposits_unavailable',
      message: 'Crypto deposits aren’t enabled yet. A payment processor is being connected.',
    });
  }

  private autoConfirmEnabled(settingsAllows: boolean): boolean {
    return DEPOSIT_AUTO_CONFIRM && settingsAllows;
  }

  async create(userId: string, dto: CreateDepositDto): Promise<DepositDto> {
    const s = await this.settings.get();
    const method = dto.method ?? 'crypto';
    if (method !== 'crypto' || !s.cryptoEnabled) {
      throw new BadRequestException({
        code: 'method_unavailable',
        message: 'Only crypto deposits are available right now. Other methods are coming soon.',
      });
    }
    const amount = Math.round(dto.amount * 100) / 100;
    if (amount < s.minDeposit) {
      throw new BadRequestException({
        code: 'below_min_deposit',
        message: `Minimum deposit is $${s.minDeposit.toFixed(2)}.`,
      });
    }
    const asset = dto.asset ?? 'USDT';
    const id = genId('dep');
    // order_id must equal our deposit id, so issue the payment first.
    const pay = await this.issuePayment(id, amount, asset); // refuses a fake address in prod
    const deposit = await this.prisma.deposit.create({
      data: {
        id,
        userId,
        amount,
        currency: 'USD',
        method,
        asset,
        address: pay.address,
        payAmount: pay.payAmount ?? null,
        payCurrency: pay.payCurrency ?? null,
        providerRef: pay.providerRef ?? null,
        status: DepositStatus.pending,
      },
    });

    // Auto-credit ONLY in dev/test (env-gated). In production the wallet is
    // credited by confirmViaWebhook() when the processor reports funds arrived,
    // or by an admin approval — never on request.
    if (this.autoConfirmEnabled(s.depositAutoConfirm)) {
      return this.confirm(deposit.id, `test-${deposit.id}`);
    }
    return this.toDto(deposit);
  }

  /**
   * Handle a crypto-processor webhook (IPN). Uses the configured provider's own
   * signature scheme (e.g. NOWPayments HMAC-SHA512 over the sorted body); falls
   * back to a generic HMAC-SHA256 x-signature over the raw body when only
   * CRYPTO_WEBHOOK_SECRET is set (a custom processor). Idempotent — retries and
   * the same event arriving twice never double-credit.
   */
  async confirmViaWebhook(
    rawBody: string,
    headers: Record<string, string | undefined>,
    body: { depositId?: string; txRef?: string },
  ): Promise<{ ok: true; status?: string }> {
    // First-class provider (NOWPayments, …).
    if (this.crypto.enabled) {
      const r = this.crypto.verifyWebhook(rawBody, headers);
      if (!r.ok) throw new UnauthorizedException({ code: 'bad_signature', message: 'Invalid webhook signature.' });
      if (!r.depositId) return { ok: true, status: 'ignored' };
      if (r.status === 'confirmed') await this.confirm(r.depositId, r.txRef);
      else if (r.status === 'failed') await this.failIfPending(r.depositId, `processor: ${this.crypto.name}`);
      return { ok: true, status: r.status };
    }

    // Generic custom processor: HMAC-SHA256 over the raw body in x-signature.
    if (!CRYPTO_WEBHOOK_SECRET) {
      throw new UnauthorizedException({ code: 'webhook_not_configured', message: 'Deposit webhook is not configured.' });
    }
    const expected = createHmac('sha256', CRYPTO_WEBHOOK_SECRET).update(rawBody).digest('hex');
    const provided = (headers['x-signature'] ?? '').trim();
    const ok =
      provided.length === expected.length &&
      timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
    if (!ok) throw new UnauthorizedException({ code: 'bad_signature', message: 'Invalid webhook signature.' });
    if (!body.depositId) throw new BadRequestException({ code: 'missing_deposit', message: 'depositId is required.' });
    await this.confirm(body.depositId, body.txRef ?? `webhook:${Date.now()}`);
    return { ok: true, status: 'confirmed' };
  }

  /** Mark a still-pending deposit failed (webhook reported failure/expiry). */
  private async failIfPending(depositId: string, reason: string): Promise<void> {
    await this.prisma.deposit.updateMany({
      where: { id: depositId, status: DepositStatus.pending },
      data: { status: DepositStatus.failed, reason },
    });
  }

  // ── per-user deposit addresses (address-based provider, e.g. Tatum) ──────
  /**
   * The caller's USDT deposit addresses (one per supported network), issued
   * lazily on first request. Requires KYC and a configured address provider.
   */
  async myAddresses(userId: string): Promise<DepositAddressDto[]> {
    if (!this.addresses.enabled) {
      throw new BadRequestException({ code: 'deposits_unavailable', message: 'Crypto deposits aren’t enabled yet.' });
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { kycStatus: true } });
    if (user?.kycStatus !== KycStatus.verified) {
      throw new BadRequestException({ code: 'kyc_required', message: 'Complete identity verification (KYC) to get a deposit address.' });
    }
    const out: DepositAddressDto[] = [];
    for (const network of this.addresses.networks) {
      out.push(await this.ensureAddress(userId, network));
    }
    return out;
  }

  private async ensureAddress(userId: string, network: DepositNetwork): Promise<DepositAddressDto> {
    const existing = await this.prisma.depositAddress.findUnique({ where: { userId_network: { userId, network } } });
    if (existing) return { network: existing.network, asset: existing.asset, address: existing.address };
    // Unique HD derivation index per network (count of existing addresses).
    const index = await this.prisma.depositAddress.count({ where: { network } });
    const gen = await this.addresses.createAddress(userId, network, index);
    try {
      const row = await this.prisma.depositAddress.create({
        data: { id: genId('da'), userId, network, asset: 'USDT', address: gen.address, providerRef: gen.providerRef, derivationIndex: gen.derivationIndex },
      });
      return { network: row.network, asset: row.asset, address: row.address };
    } catch (e) {
      // Concurrent create → unique(userId,network) violation: return the winner.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const row = await this.prisma.depositAddress.findUnique({ where: { userId_network: { userId, network } } });
        if (row) return { network: row.network, asset: row.asset, address: row.address };
      }
      throw e;
    }
  }

  /**
   * Credit a confirmed on-chain deposit that landed on a user's address. Looks up
   * the owning user by address, then reuses confirm() (idempotent). The unique
   * txRef guard means the same tx can never credit twice.
   */
  async creditFromChainDeposit(d: ChainDeposit): Promise<{ credited: boolean }> {
    if (!d.ok || !d.address || !d.network || !d.txRef || !d.amount || d.amount <= 0) return { credited: false };
    const addr = await this.prisma.depositAddress.findFirst({ where: { network: d.network, address: d.address } });
    if (!addr) {
      this.logger.warn(`chain deposit to unknown address (${d.network}) ${d.address}`);
      return { credited: false };
    }
    const amount = Math.round(d.amount * 100) / 100; // USDT ≈ USD 1:1
    let depositId: string;
    try {
      const dep = await this.prisma.deposit.create({
        data: { id: genId('dep'), userId: addr.userId, amount, currency: 'USD', method: 'crypto', asset: 'USDT', address: d.address, payCurrency: d.network, txRef: d.txRef, status: DepositStatus.pending },
      });
      depositId = dep.id;
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') return { credited: false }; // tx already processed
      throw e;
    }
    await this.confirm(depositId, d.txRef);
    return { credited: true };
  }

  /** Handle an address-provider deposit webhook (verify + credit). */
  async handleChainWebhook(rawBody: string, headers: Record<string, string | undefined>): Promise<{ ok: true; credited: boolean }> {
    const parsed = await this.addresses.parseWebhook(rawBody, headers);
    if (!parsed.ok) throw new UnauthorizedException({ code: 'bad_signature', message: 'Invalid webhook signature.' });
    const { credited } = await this.creditFromChainDeposit(parsed);
    return { ok: true, credited };
  }

  /**
   * Confirm a pending deposit and credit the wallet — idempotent: a deposit is
   * only ever credited once (webhook retries are safe).
   */
  async confirm(depositId: string, txRef?: string): Promise<DepositDto> {
    const deposit = await this.prisma.deposit.findUnique({ where: { id: depositId } });
    if (!deposit) {
      throw new NotFoundException({ code: 'deposit_not_found', message: 'Deposit not found' });
    }
    if (deposit.status === DepositStatus.confirmed) return this.toDto(deposit);

    const updated = await this.prisma.$transaction(async (tx) => {
      const d = await tx.deposit.update({
        where: { id: deposit.id },
        data: { status: DepositStatus.confirmed, txRef: txRef ?? deposit.txRef, confirmedAt: new Date() },
      });
      await this.wallet.post({
        userId: d.userId,
        type: LedgerType.deposit,
        amount: d.amount,
        refId: d.id,
        note: `Deposit ${d.asset ?? d.method}`,
        tx,
      });
      await this.maybePayReferralBonus(tx, d.userId);
      return d;
    });
    // Reached only when a previously-pending deposit was just credited (the
    // already-confirmed case returns early above). Real-time confirmation so the
    // app's "waiting for deposit" screen updates instantly (push + in-app + WS).
    await this.notifications.pushEvent(updated.userId, 'wallet.deposit', 'Deposit received', {
      body: `Your ${updated.asset ?? 'crypto'} deposit of $${updated.amount.toFixed(2)} has been credited.`,
      data: { depositId: updated.id, amount: updated.amount, asset: updated.asset, txRef: updated.txRef },
    });
    return this.toDto(updated);
  }

  /**
   * On a referred user's FIRST confirmed deposit, pay their referrer the
   * one-time signup bonus (affiliate CPA). Runs inside the confirm transaction.
   */
  private async maybePayReferralBonus(tx: any, userId: string): Promise<void> {
    const s = await this.settings.get();
    if (!s.referralEnabled || s.referralSignupBonus <= 0) return;
    const confirmed = await tx.deposit.count({ where: { userId, status: DepositStatus.confirmed } });
    if (confirmed !== 1) return; // only the first one
    const user = await tx.user.findUnique({ where: { id: userId }, select: { referredById: true } });
    if (!user?.referredById) return;
    await this.wallet.post({
      userId: user.referredById,
      type: LedgerType.referral_commission,
      amount: s.referralSignupBonus,
      refId: userId,
      note: 'Referral signup bonus',
      tx,
    });
  }

  async listMine(userId: string): Promise<DepositDto[]> {
    const rows = await this.prisma.deposit.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((d) => this.toDto(d));
  }

  // ── admin ops (manual-confirm mode + risk review) ──────────────────────
  /** Admin approves a pending deposit → credits the wallet (idempotent). */
  async adminApprove(id: string, adminId: string): Promise<DepositDto> {
    const d = await this.getOrThrow(id);
    if (d.status !== DepositStatus.pending) {
      throw new BadRequestException({ code: 'not_pending', message: `Deposit is already ${d.status}.` });
    }
    return this.confirm(id, `admin:${adminId}`);
  }

  async adminReject(id: string, adminId: string, reason: string): Promise<DepositDto> {
    const d = await this.getOrThrow(id);
    if (d.status === DepositStatus.confirmed) {
      throw new BadRequestException({ code: 'already_confirmed', message: 'Deposit already credited.' });
    }
    const updated = await this.prisma.deposit.update({
      where: { id },
      data: { status: DepositStatus.failed, decisionBy: adminId, reason },
    });
    return this.toDto(updated);
  }

  async setFlag(id: string, flagged: boolean, reason?: string): Promise<DepositDto> {
    await this.getOrThrow(id);
    const updated = await this.prisma.deposit.update({
      where: { id },
      data: { flagged, flagReason: flagged ? reason ?? 'Flagged for review' : null },
    });
    return this.toDto(updated);
  }

  private async getOrThrow(id: string): Promise<Deposit> {
    const d = await this.prisma.deposit.findUnique({ where: { id } });
    if (!d) throw new NotFoundException({ code: 'deposit_not_found', message: 'Deposit not found' });
    return d;
  }
}
