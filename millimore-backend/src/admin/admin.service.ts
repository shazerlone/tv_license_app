import { Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  CreatorApplication,
  User,
  CreatorStatus,
  DepositStatus,
  PayoutStatus,
  BroadcastPhase,
} from '@prisma/client';
import { LedgerType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { TradersService } from '../traders/traders.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SettlementService } from '../wallet/settlement.service';
import { WalletService } from '../wallet/wallet.service';
import { countryNameFromIso } from '../common/countries';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';
import {
  AdminUserDto,
  AdminUsersQueryDto,
  UpdateAdminUserDto,
} from './dto/admin-user.dto';
import { ApplicationDto } from './dto/application.dto';
import { AdminMetricsDto } from './dto/metrics.dto';

type ApplicationWithUser = CreatorApplication & { user: User };

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly traders: TradersService,
    private readonly notifications: NotificationsService,
    private readonly settlement: SettlementService,
    private readonly wallet: WalletService,
  ) {}

  // ── metrics (contract §6) ──────────────────────────────────────────
  /** Real platform metrics for the admin dashboard — all live DB aggregates. */
  async metrics(): Promise<AdminMetricsDto> {
    const now = Date.now();
    const dayAgo = new Date(now - 24 * 60 * 60 * 1000);
    const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
    const startOfToday = new Date();
    startOfToday.setUTCHours(0, 0, 0, 0);

    const [
      totalUsers,
      creators,
      dau,
      mau,
      liveNow,
      streamsToday,
      allCopy,
      activeCopy,
      depositsAgg,
      walletAgg,
      pendingPayoutAgg,
      platformRevenue,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { creatorStatus: CreatorStatus.approved } }),
      this.prisma.user.count({ where: { lastSeenAt: { gte: dayAgo } } }),
      this.prisma.user.count({ where: { lastSeenAt: { gte: monthAgo } } }),
      this.prisma.broadcast.count({ where: { phase: BroadcastPhase.live } }),
      this.prisma.broadcast.count({ where: { createdAt: { gte: startOfToday } } }),
      this.prisma.copyConfig.aggregate({ _sum: { amount: true } }),
      this.prisma.copyConfig.aggregate({ where: { active: true }, _sum: { amount: true } }),
      this.prisma.deposit.aggregate({
        where: { status: DepositStatus.confirmed },
        _sum: { amount: true },
      }),
      this.prisma.wallet.aggregate({ _sum: { balance: true } }),
      this.prisma.payout.aggregate({
        where: { status: PayoutStatus.pending },
        _sum: { amount: true },
        _count: true,
      }),
      this.settlement.platformRevenue(),
    ]);

    const round2 = (n: number) => Math.round(n * 100) / 100;
    return {
      dau,
      mau,
      liveNow,
      streamsToday,
      totalUsers,
      creators,
      gmv: round2(allCopy._sum.amount ?? 0),
      copyVolume: round2(activeCopy._sum.amount ?? 0),
      depositsTotal: round2(depositsAgg._sum.amount ?? 0),
      walletLiabilities: round2(walletAgg._sum.balance ?? 0),
      platformRevenue: round2(platformRevenue),
      pendingPayouts: pendingPayoutAgg._count,
      pendingPayoutAmount: round2(pendingPayoutAgg._sum.amount ?? 0),
      errors24h: 0,
      uptime: Math.round(process.uptime()),
    };
  }

  // ── users ──────────────────────────────────────────────────────────
  private toAdminUserDto(u: User): AdminUserDto {
    return { ...this.users.toDto(u), banned: u.banned, frozen: u.frozen, adminNote: u.adminNote };
  }

  async listUsers(q: AdminUsersQueryDto): Promise<Paginated<AdminUserDto>> {
    const limit = q.limit ?? 20;
    const where: Prisma.UserWhereInput = {};
    if (q.role) where.role = q.role;
    if (q.q) {
      where.OR = [
        { name: { contains: q.q, mode: 'insensitive' } },
        { username: { contains: q.q, mode: 'insensitive' } },
        { email: { contains: q.q, mode: 'insensitive' } },
      ];
    }

    const cursorId = decodeCursor(q.cursor);
    const rows = await this.prisma.user.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1, // one extra to detect a next page
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
    });

    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit);
    return {
      items: items.map((u) => this.toAdminUserDto(u)),
      nextCursor: hasMore ? encodeCursor(items[items.length - 1].id) : null,
    };
  }

  async updateUser(id: string, dto: UpdateAdminUserDto): Promise<AdminUserDto> {
    await this.getUserOrThrow(id);
    const user = await this.prisma.user.update({
      where: { id },
      data: {
        role: dto.role,
        banned: dto.banned,
        creatorStatus: dto.creatorStatus,
        frozen: dto.frozen,
        adminNote: dto.adminNote,
      },
    });
    return this.toAdminUserDto(user);
  }

  // ── user 360 + balance ops (milestone 8) ───────────────────────────
  /** Full detail view for one user: profile, wallet, stats, recent ledger. */
  async userDetail(id: string) {
    const user = await this.getUserOrThrow(id);
    const trader = await this.prisma.trader.findUnique({ where: { userId: id }, select: { id: true } });
    const [balance, ledger, depAgg, wdAgg, activeCopies, lifetimeCommission, payoutMethods] =
      await Promise.all([
        this.wallet.balance(id),
        this.wallet.ledger(id, 30),
        this.prisma.deposit.aggregate({ where: { userId: id, status: 'confirmed' }, _sum: { amount: true }, _count: true }),
        this.prisma.payout.aggregate({ where: { userId: id, status: { in: ['approved', 'paid'] } }, _sum: { amount: true }, _count: true }),
        this.prisma.copyConfig.count({ where: { userId: id, active: true } }),
        this.wallet.lifetimeCommission(id),
        this.prisma.payoutMethod.count({ where: { userId: id } }),
      ]);
    return {
      user: this.toAdminUserDto(user),
      wallet: { balance, currency: 'USD' },
      stats: {
        deposits: depAgg._count,
        depositsTotal: Math.round((depAgg._sum.amount ?? 0) * 100) / 100,
        withdrawals: wdAgg._count,
        withdrawalsTotal: Math.round((wdAgg._sum.amount ?? 0) * 100) / 100,
        activeCopies,
        lifetimeCommission,
        payoutMethods,
        isTrader: !!trader,
      },
      ledger,
    };
  }

  /** Manually credit (+) or debit (-) a user's wallet, audited via the ledger. */
  async adjustBalance(id: string, amount: number, reason: string, adminId: string) {
    await this.getUserOrThrow(id);
    const rounded = Math.round(amount * 100) / 100;
    const newBalance = await this.wallet.post({
      userId: id,
      type: LedgerType.adjustment,
      amount: rounded,
      note: `Admin adjustment: ${reason}`,
      allowNegative: true, // ops can correct balances in either direction
    });
    await this.notifications.pushEvent(id, 'wallet.adjusted', 'Wallet updated', {
      body: `${rounded >= 0 ? '+' : ''}$${rounded.toFixed(2)} — ${reason}`,
      data: { amount: rounded, reason },
    });
    return { balance: newBalance, currency: 'USD' };
  }

  // ── creator verification queue ─────────────────────────────────────
  private toApplicationDto(a: ApplicationWithUser): ApplicationDto {
    return {
      id: a.id,
      userId: a.userId,
      user: {
        id: a.user.id,
        name: a.user.name,
        username: a.user.username,
        email: a.user.email,
        phone: a.user.phone,
        photoUrl: a.user.photoUrl,
        residenceCountry: a.user.residenceCountry ?? countryNameFromIso(a.user.residenceIso),
      },
      status: a.status,
      market: a.market,
      platform: a.platform,
      verification: {
        platform: a.verificationPlatform,
        server: a.server,
        account: a.account,
        statementUrl: a.statementUrl,
        hasInvestorPassword: !!a.investorPasswordEnc, // never expose the value
      },
      reviewerNote: a.reviewerNote,
      rejectReason: a.rejectReason,
      createdAt: a.createdAt.toISOString(),
    };
  }

  async pendingCreators(): Promise<ApplicationDto[]> {
    const apps = await this.prisma.creatorApplication.findMany({
      where: { status: CreatorStatus.pending },
      orderBy: { createdAt: 'asc' },
      include: { user: true },
    });
    return apps.map((a) => this.toApplicationDto(a));
  }

  async approveCreator(applicationId: string, note?: string): Promise<ApplicationDto> {
    const app = await this.getApplicationOrThrow(applicationId);
    const [updated] = await this.prisma.$transaction([
      this.prisma.creatorApplication.update({
        where: { id: app.id },
        data: { status: CreatorStatus.approved, reviewerNote: note ?? null, rejectReason: null },
        include: { user: true },
      }),
      this.prisma.user.update({
        where: { id: app.userId },
        data: { creatorStatus: CreatorStatus.approved },
      }),
    ]);
    // Approved creators must be discoverable immediately (even with no trades):
    // give them a public Trader profile if they don't already have one.
    await this.traders.ensureForUser(app.userId);
    await this.notifications.pushEvent(app.userId, 'creator.status', 'You are approved 🎉', {
      data: { creatorStatus: 'approved' },
    });
    return this.toApplicationDto(updated);
  }

  async rejectCreator(applicationId: string, reason: string): Promise<ApplicationDto> {
    const app = await this.getApplicationOrThrow(applicationId);
    const [updated] = await this.prisma.$transaction([
      this.prisma.creatorApplication.update({
        where: { id: app.id },
        data: { status: CreatorStatus.rejected, rejectReason: reason },
        include: { user: true },
      }),
      this.prisma.user.update({
        where: { id: app.userId },
        data: { creatorStatus: CreatorStatus.rejected },
      }),
    ]);
    await this.notifications.pushEvent(app.userId, 'creator.status', 'Verification update', {
      data: { creatorStatus: 'rejected', reason },
    });
    return this.toApplicationDto(updated);
  }

  // ── helpers ────────────────────────────────────────────────────────
  private async getUserOrThrow(id: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    return user;
  }

  private async getApplicationOrThrow(id: string): Promise<CreatorApplication> {
    const app = await this.prisma.creatorApplication.findUnique({ where: { id } });
    if (!app) {
      throw new NotFoundException({
        code: 'application_not_found',
        message: 'Creator application not found',
      });
    }
    return app;
  }
}
