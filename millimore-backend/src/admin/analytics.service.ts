import { Injectable } from '@nestjs/common';
import { DepositStatus, LedgerType, PayoutStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const DAY_MS = 24 * 60 * 60 * 1000;
const round2 = (n: number) => Math.round(n * 100) / 100;
const dayKey = (d: Date) => d.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)

export interface AnalyticsPoint {
  date: string;
  signups: number;
  deposits: number;
  withdrawals: number;
  revenue: number;
}

/**
 * Admin analytics — daily time-series + totals + leaderboards, computed from
 * live DB rows. Bucketed in-process (portable across Postgres); for very large
 * datasets this becomes a grouped SQL query, no shape change.
 */
@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(days = 30) {
    const range = Math.min(180, Math.max(7, days));
    const since = new Date(Date.now() - (range - 1) * DAY_MS);
    since.setUTCHours(0, 0, 0, 0);

    // Empty buckets for every day in range, so the chart has no gaps.
    const buckets = new Map<string, AnalyticsPoint>();
    for (let i = 0; i < range; i++) {
      const key = dayKey(new Date(since.getTime() + i * DAY_MS));
      buckets.set(key, { date: key, signups: 0, deposits: 0, withdrawals: 0, revenue: 0 });
    }
    const add = (d: Date, field: keyof AnalyticsPoint, amount = 1) => {
      const b = buckets.get(dayKey(d));
      if (b) (b[field] as number) = round2((b[field] as number) + amount);
    };

    const [users, deposits, payouts, revenueRows, totals, topTraders] = await Promise.all([
      this.prisma.user.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      this.prisma.deposit.findMany({
        where: { status: DepositStatus.confirmed, confirmedAt: { gte: since } },
        select: { amount: true, confirmedAt: true },
      }),
      this.prisma.payout.findMany({
        where: { status: { in: [PayoutStatus.approved, PayoutStatus.paid] }, decidedAt: { gte: since } },
        select: { amount: true, decidedAt: true },
      }),
      this.prisma.ledgerEntry.findMany({
        where: { userId: 'platform', type: LedgerType.platform_fee, createdAt: { gte: since } },
        select: { amount: true, createdAt: true },
      }),
      this.computeTotals(),
      this.prisma.trader.findMany({
        orderBy: [{ copiers: 'desc' }, { aum: 'desc' }],
        take: 6,
        select: { id: true, name: true, username: true, photoUrl: true, copiers: true, aum: true, returnPercent: true },
      }),
    ]);

    for (const u of users) add(u.createdAt, 'signups');
    for (const d of deposits) if (d.confirmedAt) add(d.confirmedAt, 'deposits', d.amount);
    for (const p of payouts) if (p.decidedAt) add(p.decidedAt, 'withdrawals', p.amount);
    for (const r of revenueRows) add(r.createdAt, 'revenue', r.amount);

    return {
      range,
      series: Array.from(buckets.values()),
      totals,
      topTraders,
    };
  }

  private async computeTotals() {
    const monthAgo = new Date(Date.now() - 30 * DAY_MS);
    const [
      users, creators, kycVerified, depositsAgg, withdrawalsAgg, revenueAgg, copyAgg, walletAgg, activeCopiers,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { creatorStatus: 'approved' } }),
      this.prisma.user.count({ where: { kycStatus: 'verified' } }),
      this.prisma.deposit.aggregate({ where: { status: DepositStatus.confirmed }, _sum: { amount: true } }),
      this.prisma.payout.aggregate({ where: { status: { in: [PayoutStatus.approved, PayoutStatus.paid] } }, _sum: { amount: true } }),
      this.prisma.ledgerEntry.aggregate({ where: { userId: 'platform', type: LedgerType.platform_fee }, _sum: { amount: true } }),
      this.prisma.copyConfig.aggregate({ where: { active: true }, _sum: { amount: true } }),
      this.prisma.wallet.aggregate({ _sum: { balance: true } }),
      this.prisma.copyConfig.count({ where: { active: true } }),
    ]);
    const newUsers30d = await this.prisma.user.count({ where: { createdAt: { gte: monthAgo } } });
    return {
      users,
      newUsers30d,
      creators,
      kycVerified,
      depositsTotal: round2(depositsAgg._sum.amount ?? 0),
      withdrawalsTotal: round2(withdrawalsAgg._sum.amount ?? 0),
      revenueTotal: round2(revenueAgg._sum.amount ?? 0),
      copyVolume: round2(copyAgg._sum.amount ?? 0),
      walletLiabilities: round2(walletAgg._sum.balance ?? 0),
      activeCopies: activeCopiers,
    };
  }
}
