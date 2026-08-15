import { BadRequestException, Injectable, NotFoundException, UnauthorizedException, Logger } from '@nestjs/common';
import { Deposit, DepositStatus, LedgerType } from '@prisma/client';
import { randomBytes, createHmac, timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { SettingsService } from '../settings/settings.service';
import { genId } from '../common/ids';
import { CreateDepositDto, DepositDto, DepositMethodDto } from './dto/deposit.dto';

// Hard production safety gate: auto-crediting a deposit without real on-chain
// confirmation is a DEV-ONLY convenience. It is OFF unless DEPOSIT_AUTO_CONFIRM
// is explicitly "true", regardless of the admin PlatformSettings toggle — so a
// misconfigured setting can never mint real balance in production.
const DEPOSIT_AUTO_CONFIRM = process.env.DEPOSIT_AUTO_CONFIRM === 'true';
// Real crypto processor (e.g. NOWPayments/Coinbase Commerce/BitPay or an HD
// wallet service) that issues real deposit addresses and calls our webhook on
// confirmation. Unset in dev; required before prod crypto deposits are enabled.
const CRYPTO_DEPOSIT_PROVIDER = (process.env.CRYPTO_DEPOSIT_PROVIDER ?? '').trim();
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
  ) {}

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
   * Issue a deposit address. In production this must come from a real crypto
   * processor; we NEVER hand out a fake address there (users would send real
   * funds into the void). Dev/test (DEPOSIT_AUTO_CONFIRM=true) uses a mock.
   */
  private async depositAddress(asset: string): Promise<string> {
    if (CRYPTO_DEPOSIT_PROVIDER) {
      // TODO: call the configured processor to generate a real address.
      // Left unwired until a provider + creds are chosen; fail closed for now.
      throw new BadRequestException({
        code: 'deposits_unavailable',
        message: 'Crypto deposits are being set up. Please try again soon.',
      });
    }
    if (DEPOSIT_AUTO_CONFIRM) return this.mockAddress(asset); // dev/test only
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
    const address = await this.depositAddress(asset); // refuses a fake address in prod
    const deposit = await this.prisma.deposit.create({
      data: {
        id: genId('dep'),
        userId,
        amount,
        currency: 'USD',
        method,
        asset,
        address,
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
   * Confirm a deposit from a crypto-processor webhook. Verifies the HMAC-SHA256
   * signature over the raw body with CRYPTO_WEBHOOK_SECRET before crediting, then
   * confirms idempotently. Wire the chosen provider's webhook to this endpoint.
   */
  async confirmViaWebhook(rawBody: string, signature: string | undefined, body: { depositId?: string; txRef?: string }): Promise<{ ok: true }> {
    if (!CRYPTO_WEBHOOK_SECRET) {
      throw new UnauthorizedException({ code: 'webhook_not_configured', message: 'Deposit webhook is not configured.' });
    }
    const expected = createHmac('sha256', CRYPTO_WEBHOOK_SECRET).update(rawBody).digest('hex');
    const provided = (signature ?? '').trim();
    const ok =
      provided.length === expected.length &&
      timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
    if (!ok) {
      throw new UnauthorizedException({ code: 'bad_signature', message: 'Invalid webhook signature.' });
    }
    if (!body.depositId) {
      throw new BadRequestException({ code: 'missing_deposit', message: 'depositId is required.' });
    }
    await this.confirm(body.depositId, body.txRef ?? `webhook:${Date.now()}`);
    return { ok: true };
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
