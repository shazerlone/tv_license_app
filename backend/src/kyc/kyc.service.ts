import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';
import { KYC_PROVIDER, KycProvider, KycStartResult } from './kyc.types';

@Injectable()
export class KycService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    @Inject(KYC_PROVIDER) private readonly provider: KycProvider,
  ) {}

  /** Begin verification: ensure a provider applicant + return an SDK token. */
  async start(userId: string): Promise<KycStartResult> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    if (user.kycStatus === KycStatus.verified) {
      return { provider: user.kycProvider ?? this.provider.name, applicantId: user.kycApplicantId ?? '', accessToken: '', manual: user.kycProvider === 'manual' };
    }
    const res = await this.provider.start({ userId, email: user.email, name: user.name });
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        kycProvider: res.provider,
        kycApplicantId: res.applicantId,
        // move to pending unless already decided
        kycStatus: user.kycStatus === KycStatus.none ? KycStatus.pending : user.kycStatus,
      },
    });
    return res;
  }

  /** Manual funnel: store the applicant's details + document image URLs and move
   *  them to pending review. Used when no automated provider (Sumsub) is wired. */
  async submitManual(userId: string, details: Record<string, unknown>): Promise<{ kycStatus: KycStatus }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { kycStatus: true } });
    if (!user) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    if (user.kycStatus === KycStatus.verified) return { kycStatus: KycStatus.verified };
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        kycProvider: 'manual',
        kycStatus: KycStatus.pending,
        kycReason: null,
        kycDetails: { ...details, submittedAt: new Date().toISOString() } as Prisma.InputJsonValue,
      },
    });
    return { kycStatus: KycStatus.pending };
  }

  async status(userId: string): Promise<{ kycStatus: KycStatus; provider: string | null; reason: string | null }> {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { kycStatus: true, kycProvider: true, kycReason: true },
    });
    return {
      kycStatus: u?.kycStatus ?? KycStatus.none,
      provider: u?.kycProvider ?? null,
      reason: u?.kycReason ?? null,
    };
  }

  /** Provider webhook (Sumsub) → normalized status update on the matching user. */
  async handleWebhook(headers: Record<string, string>, rawBody: string): Promise<{ ok: boolean }> {
    const parsed = this.provider.parseWebhook(headers, rawBody);
    if (!parsed) return { ok: false };
    const user = await this.prisma.user.findFirst({ where: { kycApplicantId: parsed.applicantId } });
    if (!user) return { ok: false };
    await this.setStatus(user.id, parsed.status, parsed.reason);
    return { ok: true };
  }

  /** Apply a status change + notify the user. Shared by webhook and admin. */
  async setStatus(userId: string, status: KycStatus, reason?: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { kycStatus: status, kycReason: reason ?? null },
    });
    await this.notifications.pushEvent(userId, 'kyc.status', 'Identity verification update', {
      body: status === KycStatus.verified ? 'Your identity is verified ✅' : reason ?? `KYC ${status}`,
      data: { kycStatus: status, reason },
    });
  }

  async adminList(q: { status?: string; limit?: number; cursor?: string }): Promise<Paginated<any>> {
    const limit = q.limit ?? 20;
    const where: Prisma.UserWhereInput = {};
    if (q.status) where.kycStatus = q.status as KycStatus;
    else where.kycStatus = { not: KycStatus.none };
    const cursorId = decodeCursor(q.cursor);
    const rows = await this.prisma.user.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true, name: true, username: true, email: true,
        kycStatus: true, kycProvider: true, kycApplicantId: true, kycReason: true,
        residenceCountry: true, createdAt: true,
      },
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit);
    return {
      items: items.map((u) => ({ ...u, createdAt: u.createdAt.toISOString() })),
      nextCursor: hasMore ? encodeCursor(items[items.length - 1].id) : null,
    };
  }
}
