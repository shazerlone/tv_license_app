import { Injectable } from '@nestjs/common';
import { CreatorStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { UsersService } from '../users/users.service';
import { genId } from '../common/ids';
import { CreatorStatusDto, ApplyCreatorDto, CreatorStatsDto } from './dto/creator.dto';
import { UserDto } from '../users/dto/user.dto';

@Injectable()
export class CreatorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
    private readonly users: UsersService,
  ) {}

  /** Creator dashboard stats (contract §5b). Real copiers/AUM from copy configs. */
  async stats(userId: string): Promise<CreatorStatsDto> {
    const trader = await this.prisma.trader.findUnique({ where: { userId } });
    if (!trader) return { followers: 0, copiers: 0, aum: 0, return30d: 0, earnings: 0 };

    const [followers, copyAgg] = await Promise.all([
      this.prisma.subscription.count({ where: { traderId: trader.id } }),
      this.prisma.copyConfig.aggregate({
        where: { traderId: trader.id, active: true },
        _count: true,
        _sum: { amount: true },
      }),
    ]);
    return {
      followers,
      copiers: copyAgg._count,
      aum: copyAgg._sum.amount ?? 0,
      return30d: trader.returnPercent,
      earnings: 0, // real payouts land in milestone 6
    };
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
