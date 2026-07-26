import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, CreatorApplication, User, CreatorStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { countryNameFromIso } from '../common/countries';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';
import {
  AdminUserDto,
  AdminUsersQueryDto,
  UpdateAdminUserDto,
} from './dto/admin-user.dto';
import { ApplicationDto } from './dto/application.dto';

type ApplicationWithUser = CreatorApplication & { user: User };

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
  ) {}

  // ── users ──────────────────────────────────────────────────────────
  private toAdminUserDto(u: User): AdminUserDto {
    return { ...this.users.toDto(u), banned: u.banned };
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
        // Keep residenceCountry consistent if an admin ever changes residence.
      },
    });
    return this.toAdminUserDto(user);
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
    // TODO(milestone 5): emit WS `user` → creator.status event to the applicant.
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
    // TODO(milestone 5): emit WS `user` → creator.status event to the applicant.
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
