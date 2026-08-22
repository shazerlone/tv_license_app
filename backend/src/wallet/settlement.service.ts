import { Injectable, Logger } from '@nestjs/common';
import { LedgerType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { SettingsService } from '../settings/settings.service';
import { genId } from '../common/ids';

const round2 = (n: number) => Math.round(n * 100) / 100;

/** Ledger owner for Millimore's own revenue (no wallet FK; ledger-only). */
export const PLATFORM_LEDGER_USER = 'platform';

export interface SettleInput {
  copierUserId: string;
  trader: { id: string; userId: string | null; commissionPercent: number };
  /** Capital originally allocated to this copy (returned to the copier). */
  principal: number;
  /** Realized P/L booked across the closed positions. */
  realizedPnl: number;
  refId?: string;
}

export interface SettleResult {
  netToCopier: number; // principal + profit − fee (or principal − loss)
  fee: number;
  traderCut: number;
  platformCut: number;
}

/**
 * Settles a stopped copy: returns the copier's principal, books realized P/L,
 * and on a PROFIT charges the trader-set performance fee — splitting it into the
 * trader's earnings and Millimore's share (PLATFORM_FEE_SHARE). Losses are
 * capped at the allocated principal (no negative wallet in this model). All
 * writes happen in one transaction so the books never tear.
 */
@Injectable()
export class SettlementService {
  private readonly log = new Logger('Settlement');

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallet: WalletService,
    private readonly settings: SettingsService,
  ) {}

  /** Millimore's share of the trader's performance fee (admin-editable). */
  private async platformFeeShare(): Promise<number> {
    const s = await this.settings.get();
    const v = s.platformFeeShare;
    return Number.isFinite(v) && v >= 0 && v <= 1 ? v : 0.3;
  }

  private async recordPlatformFee(
    tx: Prisma.TransactionClient,
    amount: number,
    refId?: string,
  ): Promise<void> {
    if (amount <= 0) return;
    const agg = await tx.ledgerEntry.aggregate({
      where: { userId: PLATFORM_LEDGER_USER, type: LedgerType.platform_fee },
      _sum: { amount: true },
    });
    const balanceAfter = round2((agg._sum.amount ?? 0) + amount);
    await tx.ledgerEntry.create({
      data: {
        id: genId('led'),
        userId: PLATFORM_LEDGER_USER,
        type: LedgerType.platform_fee,
        amount: round2(amount),
        balanceAfter,
        currency: 'USD',
        refId: refId ?? null,
        note: 'Platform share of performance fee',
      },
    });
  }

  async settle(input: SettleInput): Promise<SettleResult> {
    const principal = round2(Math.max(0, input.principal));
    // Can't lose more than what was allocated in this model.
    const effectivePnl = round2(Math.max(input.realizedPnl, -principal));
    const commissionPct = Math.min(30, Math.max(0, input.trader.commissionPercent ?? 0));

    let fee = 0;
    let traderCut = 0;
    let platformCut = 0;
    if (effectivePnl > 0 && commissionPct > 0) {
      const share = await this.platformFeeShare();
      fee = round2((effectivePnl * commissionPct) / 100);
      platformCut = round2(fee * share);
      traderCut = round2(fee - platformCut);
    }

    return this.prisma.$transaction(async (tx) => {
      // 1) Return principal + book P/L to the copier.
      await this.wallet.post({
        userId: input.copierUserId,
        type: LedgerType.copy_return,
        amount: principal,
        refId: input.refId,
        note: 'Copy principal returned',
        tx,
      });
      await this.wallet.post({
        userId: input.copierUserId,
        type: LedgerType.trade_pnl,
        amount: effectivePnl,
        refId: input.refId,
        note: 'Realized copy P/L',
        tx,
      });

      // 2) On profit, take the performance fee from the copier and split it.
      if (fee > 0) {
        await this.wallet.post({
          userId: input.copierUserId,
          type: LedgerType.commission,
          amount: -fee,
          refId: input.refId,
          note: `Performance fee ${commissionPct}%`,
          tx,
        });
        // Trader's earnings (if the trader is a real app user).
        if (input.trader.userId) {
          await this.wallet.post({
            userId: input.trader.userId,
            type: LedgerType.commission_earned,
            amount: traderCut,
            refId: input.refId,
            note: 'Copier performance fee',
            tx,
          });
        } else {
          // Orphan trader (seeded, no user): fee accrues entirely to platform.
          platformCut = round2(platformCut + traderCut);
          traderCut = 0;
        }

        // Referral (IB) revenue share: if the copier was referred, pay the
        // referrer a slice of Millimore's cut — booked out of the platform fee.
        const referralAmount = await this.creditReferralShare(tx, input.copierUserId, platformCut);
        await this.recordPlatformFee(tx, round2(platformCut - referralAmount), input.refId);
      }

      const netToCopier = round2(principal + effectivePnl - fee);
      this.log.debug(
        `settle copier=${input.copierUserId} pnl=${effectivePnl} fee=${fee} trader=${traderCut} platform=${platformCut}`,
      );
      return { netToCopier, fee, traderCut, platformCut };
    });
  }

  /**
   * Pay the copier's referrer a share of Millimore's platform cut (affiliate/IB
   * revenue share). Returns the amount paid so the caller books the net platform
   * fee. No-op when referrals are off or the copier wasn't referred.
   */
  private async creditReferralShare(
    tx: Prisma.TransactionClient,
    copierUserId: string,
    platformCut: number,
  ): Promise<number> {
    if (platformCut <= 0) return 0;
    const s = await this.settings.get();
    if (!s.referralEnabled || s.referralRevenueShare <= 0) return 0;
    const copier = await tx.user.findUnique({
      where: { id: copierUserId },
      select: { referredById: true },
    });
    if (!copier?.referredById) return 0;
    const amount = round2(platformCut * s.referralRevenueShare);
    if (amount <= 0) return 0;
    await this.wallet.post({
      userId: copier.referredById,
      type: LedgerType.referral_commission,
      amount,
      refId: copierUserId,
      note: 'Referral revenue share',
      tx,
    });
    return amount;
  }

  /** Total revenue Millimore has booked (sum of platform_fee ledger rows). */
  async platformRevenue(): Promise<number> {
    const agg = await this.prisma.ledgerEntry.aggregate({
      where: { userId: PLATFORM_LEDGER_USER, type: LedgerType.platform_fee },
      _sum: { amount: true },
    });
    return round2(agg._sum.amount ?? 0);
  }
}
