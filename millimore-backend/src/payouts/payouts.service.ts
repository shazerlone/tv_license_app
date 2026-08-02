import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { LedgerType, Payout, PayoutStatus, Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletService } from '../wallet/wallet.service';
import { genId } from '../common/ids';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';
import {
  AdminPayoutDto,
  AdminPayoutsQueryDto,
  PayoutDto,
  RequestPayoutDto,
} from './dto/payout.dto';

/**
 * Withdrawals from the Millimore wallet. Requesting a withdrawal immediately
 * HOLDS the funds (debits the wallet) so a user can't double-spend; an admin
 * then approves (funds already removed → mark done) or rejects (funds refunded).
 * All balance changes go through the wallet ledger.
 */
@Injectable()
export class PayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly wallet: WalletService,
  ) {}

  private toDto(p: Payout): PayoutDto {
    return {
      id: p.id,
      userId: p.userId,
      amount: p.amount,
      currency: p.currency,
      status: p.status,
      method: p.method,
      note: p.note,
      reason: p.reason,
      createdAt: p.createdAt.toISOString(),
      decidedAt: p.decidedAt?.toISOString() ?? null,
    };
  }

  /** POST /creator/payouts — request a withdrawal; holds funds immediately. */
  async request(userId: string, dto: RequestPayoutDto): Promise<PayoutDto> {
    const amount = Math.round(dto.amount * 100) / 100;
    return this.prisma.$transaction(async (tx) => {
      const payout = await tx.payout.create({
        data: {
          id: genId('po'),
          userId,
          amount,
          currency: 'USD',
          status: PayoutStatus.pending,
          method: dto.method ?? null,
          note: dto.note ?? null,
        },
      });
      // Hold the funds now — throws (rolls back) if the balance is too low.
      await this.wallet.post({
        userId,
        type: LedgerType.withdrawal_hold,
        amount: -amount,
        refId: payout.id,
        note: 'Withdrawal requested',
        tx,
      });
      return this.toDto(payout);
    });
  }

  /** GET /creator/payouts — my withdrawal history. */
  async listMine(userId: string): Promise<PayoutDto[]> {
    const rows = await this.prisma.payout.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((r) => this.toDto(r));
  }

  // ── admin ────────────────────────────────────────────────────────────
  private toAdminDto(p: Payout & { user: User }): AdminPayoutDto {
    return {
      ...this.toDto(p),
      requester: {
        id: p.user.id,
        name: p.user.name,
        username: p.user.username,
        email: p.user.email,
      },
    };
  }

  async adminList(q: AdminPayoutsQueryDto): Promise<Paginated<AdminPayoutDto>> {
    const limit = q.limit ?? 20;
    const where: Prisma.PayoutWhereInput = {};
    if (q.status) where.status = q.status as PayoutStatus;

    const cursorId = decodeCursor(q.cursor);
    const rows = await this.prisma.payout.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      include: { user: true },
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit);
    return {
      items: items.map((r) => this.toAdminDto(r)),
      nextCursor: hasMore ? encodeCursor(items[items.length - 1].id) : null,
    };
  }

  /** Approve a pending withdrawal — funds were already held at request time. */
  async approve(id: string, adminId: string, reason?: string): Promise<AdminPayoutDto> {
    const payout = await this.getPendingOrThrow(id);
    const updated = await this.prisma.payout.update({
      where: { id: payout.id },
      data: {
        status: PayoutStatus.approved,
        decisionBy: adminId,
        reason: reason ?? null,
        decidedAt: new Date(),
      },
      include: { user: true },
    });
    await this.notifications.pushEvent(updated.userId, 'payout.status', 'Payout approved', {
      body: `Your $${updated.amount.toFixed(2)} withdrawal was approved.`,
      data: { status: 'approved' },
    });
    return this.toAdminDto(updated);
  }

  /** Reject a pending withdrawal — refund the held funds to the wallet. */
  async reject(id: string, adminId: string, reason: string): Promise<AdminPayoutDto> {
    const payout = await this.getPendingOrThrow(id);
    const updated = await this.prisma.$transaction(async (tx) => {
      const p = await tx.payout.update({
        where: { id: payout.id },
        data: {
          status: PayoutStatus.rejected,
          decisionBy: adminId,
          reason,
          decidedAt: new Date(),
        },
        include: { user: true },
      });
      await this.wallet.post({
        userId: p.userId,
        type: LedgerType.withdrawal_refund,
        amount: p.amount,
        refId: p.id,
        note: 'Withdrawal rejected — funds returned',
        tx,
      });
      return p;
    });
    await this.notifications.pushEvent(updated.userId, 'payout.status', 'Payout update', {
      body: reason,
      data: { status: 'rejected', reason },
    });
    return this.toAdminDto(updated);
  }

  private async getPendingOrThrow(id: string): Promise<Payout> {
    const payout = await this.prisma.payout.findUnique({ where: { id } });
    if (!payout) {
      throw new NotFoundException({ code: 'payout_not_found', message: 'Payout not found' });
    }
    if (payout.status !== PayoutStatus.pending) {
      throw new BadRequestException({
        code: 'payout_not_pending',
        message: `Payout is already ${payout.status}.`,
      });
    }
    return payout;
  }
}
