import { BadRequestException, Injectable } from '@nestjs/common';
import { CreatorStatus, PayoutStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { UsersService } from '../users/users.service';
import { WalletService } from '../wallet/wallet.service';
import { genId } from '../common/ids';
import { CreatorStatusDto, ApplyCreatorDto, CreatorStatsDto } from './dto/creator.dto';
import { UserDto } from '../users/dto/user.dto';

@Injectable()
export class CreatorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
    private readonly users: UsersService,
    private readonly wallet: WalletService,
  ) {}

  /** Creator dashboard stats (contract §5b). Real copiers/AUM from copy configs. */
  async stats(userId: string): Promise<CreatorStatsDto> {
    const trader = await this.prisma.trader.findUnique({ where: { userId } });
    if (!trader) return { followers: 0, copiers: 0, aum: 0, return30d: 0, earnings: 0 };

    const [followers, copyAgg, lifetime] = await Promise.all([
      this.prisma.subscription.count({ where: { traderId: trader.id } }),
      this.prisma.copyConfig.aggregate({
        where: { traderId: trader.id, active: true },
        _count: true,
        _sum: { amount: true },
      }),
      this.wallet.lifetimeCommission(userId),
    ]);
    return {
      followers,
      copiers: copyAgg._count,
      aum: copyAgg._sum.amount ?? 0,
      return30d: trader.returnPercent,
      earnings: lifetime, // real: lifetime performance-fee commission earned
    };
  }

  /**
   * Creator earnings & payouts (contract §5b) — now real. `balance` is the
   * withdrawable wallet balance, `pending` is money in open withdrawal requests,
   * and `history` lists recent withdrawals.
   */
  async earnings(userId: string) {
    const [balance, lifetime, pendingAgg, payouts] = await Promise.all([
      this.wallet.balance(userId),
      this.wallet.lifetimeCommission(userId),
      this.prisma.payout.aggregate({
        where: { userId, status: PayoutStatus.pending },
        _sum: { amount: true },
      }),
      this.prisma.payout.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    return {
      balance,
      currency: 'USD',
      pending: pendingAgg._sum.amount ?? 0,
      lifetimeEarned: lifetime,
      history: payouts.map((p) => ({
        id: p.id,
        amount: p.amount,
        status: p.status,
        method: p.method,
        createdAt: p.createdAt.toISOString(),
      })),
    };
  }

  /** Read the trader's current performance-fee percentage. */
  async getCommission(userId: string): Promise<{ commissionPercent: number }> {
    const trader = await this.prisma.trader.findUnique({
      where: { userId },
      select: { commissionPercent: true },
    });
    return { commissionPercent: trader?.commissionPercent ?? 20 };
  }

  /** Set the trader's performance-fee percentage (1–30%, contract wallet model). */
  async setCommission(userId: string, percent: number): Promise<{ commissionPercent: number }> {
    const trader = await this.prisma.trader.findUnique({ where: { userId } });
    if (!trader) {
      throw new BadRequestException({
        code: 'not_a_trader',
        message: 'Only approved creators can set a commission.',
      });
    }
    const clamped = Math.min(30, Math.max(1, Math.round(percent)));
    await this.prisma.trader.update({
      where: { id: trader.id },
      data: { commissionPercent: clamped },
    });
    return { commissionPercent: clamped };
  }

  /** Users who follow this creator (contract §5b "see who copies you"). */
  async followers(userId: string): Promise<UserDto[]> {
    const trader = await this.prisma.trader.findUnique({ where: { userId } });
    if (!trader) return [];
    const subs = await this.prisma.subscription.findMany({
      where: { traderId: trader.id },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { user: true },
    });
    return subs.map((s) => this.users.toDto(s.user));
  }

  async getStatus(userId: string): Promise<CreatorStatusDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { creatorStatus: true },
    });
    const creatorStatus = user?.creatorStatus ?? CreatorStatus.none;

    let reason: string | null = null;
    if (creatorStatus === CreatorStatus.rejected || creatorStatus === CreatorStatus.suspended) {
      const latest = await this.prisma.creatorApplication.findFirst({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        select: { rejectReason: true },
      });
      reason = latest?.rejectReason ?? null;
    }
    return { creatorStatus, reason };
  }

  /**
   * Apply to become a verified creator (contract §4.2). Opens a fresh pending
   * application and moves the user to role=creator, creatorStatus=pending —
   * consistent with POST /auth/register/creator. Admin flips the status later.
   */
  async apply(userId: string, dto: ApplyCreatorDto): Promise<CreatorStatusDto> {
    const v = dto.verification;
    await this.prisma.creatorApplication.create({
      data: {
        id: genId('capp'),
        userId,
        status: CreatorStatus.pending,
        market: dto.market,
        platform: dto.platform,
        verificationPlatform: v.platform,
        server: v.server,
        account: v.account,
        statementUrl: v.statementUrl,
        investorPasswordEnc: v.investorPassword
          ? this.crypto.encrypt(v.investorPassword)
          : null,
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        role: Role.creator,
        creatorStatus: CreatorStatus.pending,
        market: dto.market,
        platform: dto.platform,
      },
    });

    return { creatorStatus: CreatorStatus.pending };
  }
}
