import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Deposit, DepositStatus, LedgerType } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { SettingsService } from '../settings/settings.service';
import { genId } from '../common/ids';
import { CreateDepositDto, DepositDto, DepositMethodDto } from './dto/deposit.dto';

/**
 * Deposits into the Millimore wallet. Method availability, the minimum amount,
 * and auto-confirm all come from admin-editable PlatformSettings. In test mode
 * deposits confirm and credit the wallet immediately; in production a crypto
 * webhook (or admin approval) calls `confirm()` exactly once when funds arrive.
 */
@Injectable()
export class DepositsService {
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

  /** A placeholder deposit address (a real crypto processor issues these). */
  private mockAddress(asset: string): string {
    const prefix = asset === 'BTC' ? 'bc1' : '0x';
    return `${prefix}${randomBytes(18).toString('hex')}`;
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
    const deposit = await this.prisma.deposit.create({
      data: {
        id: genId('dep'),
        userId,
        amount,
        currency: 'USD',
        method,
        asset,
        address: this.mockAddress(asset),
        status: DepositStatus.pending,
      },
    });

    if (s.depositAutoConfirm) {
      return this.confirm(deposit.id, `test-${deposit.id}`);
    }
    return this.toDto(deposit);
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
