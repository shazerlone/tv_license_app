import { Injectable } from '@nestjs/common';
import { CreatorStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { genId } from '../common/ids';
import { CreatorStatusDto, ApplyCreatorDto } from './dto/creator.dto';

@Injectable()
export class CreatorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
  ) {}

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
