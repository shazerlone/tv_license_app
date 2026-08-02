import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';

/**
 * Append-only audit trail of privileged actions. Every admin decision
 * (approve/reject/flag/settings/KYC) records one row — the paper trail a
 * regulated fintech is expected to keep. Never updated or deleted.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(
    adminId: string,
    action: string,
    targetType: string,
    targetId: string,
    meta?: Record<string, unknown>,
  ): Promise<void> {
    await this.prisma.adminAuditLog.create({
      data: {
        id: genId('aud'),
        adminId,
        action,
        targetType,
        targetId,
        meta: (meta ?? undefined) as object | undefined,
      },
    });
  }

  async list(q: { limit?: number; cursor?: string; targetType?: string }): Promise<Paginated<any>> {
    const limit = q.limit ?? 30;
    const cursorId = decodeCursor(q.cursor);
    const rows = await this.prisma.adminAuditLog.findMany({
      where: q.targetType ? { targetType: q.targetType } : {},
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map((r) => ({
      id: r.id,
      adminId: r.adminId,
      action: r.action,
      targetType: r.targetType,
      targetId: r.targetId,
      meta: r.meta,
      createdAt: r.createdAt.toISOString(),
    }));
    return {
      items,
      nextCursor: hasMore ? encodeCursor(items[items.length - 1].id) : null,
    };
  }
}
