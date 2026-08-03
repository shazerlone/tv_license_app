import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DepositStatus, LedgerType } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';

const round2 = (n: number) => Math.round(n * 100) / 100;

/**
 * Referral / affiliate (IB) program. Each user gets a share code; referred users
 * are linked back via `referredById`. Referrers earn a slice of Millimore's
 * revenue from their referrals (paid in SettlementService) plus an optional
 * first-deposit bonus (paid in DepositsService). This service owns the code,
 * the dashboard, and the referred-users list.
 */
@Injectable()
export class ReferralsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
    private readonly config: ConfigService,
  ) {}

  private newCode(): string {
    // 7 chars, uppercase, unambiguous-ish (base32 of random bytes).
    return randomBytes(5).toString('hex').slice(0, 7).toUpperCase();
  }

  /** Ensure the user has a unique referral code, creating one if missing. */
  async ensureCode(userId: string): Promise<string> {
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: { referralCode: true } });
    if (!u) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    if (u.referralCode) return u.referralCode;
    for (let i = 0; i < 6; i++) {
      const code = this.newCode();
      const clash = await this.prisma.user.findUnique({ where: { referralCode: code }, select: { id: true } });
      if (!clash) {
        await this.prisma.user.update({ where: { id: userId }, data: { referralCode: code } });
        return code;
      }
    }
    throw new BadRequestException({ code: 'code_generation_failed', message: 'Could not allocate a referral code.' });
  }

  private link(code: string): string {
    const base = this.config.get<string>('REFERRAL_LINK_BASE', 'https://millimore.app/r/');
    return `${base}${code}`;
  }

  /** GET /referrals/me — the user's referral dashboard. */
  async mine(userId: string) {
    const code = await this.ensureCode(userId);
    const s = await this.settings.get();
    const monthAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const [referred, activeReferred, earnedAgg, earned30Agg] = await Promise.all([
      this.prisma.user.count({ where: { referredById: userId } }),
      this.prisma.user.count({ where: { referredById: userId, deposits: { some: { status: DepositStatus.confirmed } } } }),
      this.prisma.ledgerEntry.aggregate({ where: { userId, type: LedgerType.referral_commission }, _sum: { amount: true } }),
      this.prisma.ledgerEntry.aggregate({ where: { userId, type: LedgerType.referral_commission, createdAt: { gte: monthAgo } }, _sum: { amount: true } }),
    ]);
    return {
      code,
      link: this.link(code),
      enabled: s.referralEnabled,
      revenueSharePercent: round2(s.referralRevenueShare * 100),
      signupBonus: s.referralSignupBonus,
      stats: {
        referred,
        activeReferred,
        totalEarned: round2(earnedAgg._sum.amount ?? 0),
        earned30d: round2(earned30Agg._sum.amount ?? 0),
      },
    };
  }

  /** GET /referrals — people I referred, with what I earned from each. */
  async listReferred(userId: string) {
    const users = await this.prisma.user.findMany({
      where: { referredById: userId },
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true, name: true, username: true, photoUrl: true, kycStatus: true, createdAt: true,
        deposits: { where: { status: DepositStatus.confirmed }, select: { id: true }, take: 1 },
      },
    });
    // Earnings per referred user (refId = the referred user's id).
    const earnings = await this.prisma.ledgerEntry.groupBy({
      by: ['refId'],
      where: { userId, type: LedgerType.referral_commission },
      _sum: { amount: true },
    });
    const byRef = new Map(earnings.map((e) => [e.refId, round2(e._sum.amount ?? 0)]));
    return users.map((u) => ({
      id: u.id,
      name: u.name,
      username: u.username,
      photoUrl: u.photoUrl,
      kycVerified: u.kycStatus === 'verified',
      hasDeposited: u.deposits.length > 0,
      joinedAt: u.createdAt.toISOString(),
      earned: byRef.get(u.id) ?? 0,
    }));
  }

  /** Resolve a code → referrer user id (used at registration). */
  async resolveReferrer(code?: string): Promise<{ id: string; code: string } | null> {
    if (!code) return null;
    const u = await this.prisma.user.findUnique({
      where: { referralCode: code.trim().toUpperCase() },
      select: { id: true, referralCode: true },
    });
    return u?.referralCode ? { id: u.id, code: u.referralCode } : null;
  }

  /** POST /referrals/apply — attach a referral code after signup (once). */
  async apply(userId: string, code: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId }, select: { referredById: true } });
    if (me?.referredById) {
      throw new BadRequestException({ code: 'already_referred', message: 'A referral is already applied to your account.' });
    }
    const referrer = await this.resolveReferrer(code);
    if (!referrer) throw new BadRequestException({ code: 'invalid_code', message: 'That referral code is not valid.' });
    if (referrer.id === userId) throw new BadRequestException({ code: 'self_referral', message: 'You cannot refer yourself.' });
    await this.prisma.user.update({
      where: { id: userId },
      data: { referredById: referrer.id, referredByCode: referrer.code },
    });
    return { ok: true };
  }

  // ── admin ──────────────────────────────────────────────────────────
  /** Top referrers by earnings, for the admin console. */
  async adminTopReferrers(limit = 50) {
    const grouped = await this.prisma.ledgerEntry.groupBy({
      by: ['userId'],
      where: { type: LedgerType.referral_commission },
      _sum: { amount: true },
      orderBy: { _sum: { amount: 'desc' } },
      take: limit,
    });
    const ids = grouped.map((g) => g.userId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: ids } },
      select: { id: true, name: true, username: true, referralCode: true },
    });
    const byId = new Map(users.map((u) => [u.id, u]));
    const counts = await this.prisma.user.groupBy({
      by: ['referredById'],
      where: { referredById: { in: ids } },
      _count: true,
    });
    const countBy = new Map(counts.map((c) => [c.referredById, c._count]));
    return grouped.map((g) => {
      const u = byId.get(g.userId);
      return {
        id: g.userId,
        name: u?.name ?? g.userId,
        username: u?.username ?? '',
        code: u?.referralCode ?? null,
        referred: countBy.get(g.userId) ?? 0,
        earned: round2(g._sum.amount ?? 0),
      };
    });
  }
}
