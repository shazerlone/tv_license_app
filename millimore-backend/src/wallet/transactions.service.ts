import { Injectable } from '@nestjs/common';
import { DepositStatus, LedgerType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** A normalized row for the user's "Transactions" screen. */
export interface UserTxn {
  id: string;
  kind: 'deposit' | 'withdrawal' | 'trade' | 'commission' | 'fee' | 'transfer';
  title: string;
  amount: number; // signed
  currency: string;
  status: string; // completed | pending | rejected
  createdAt: string;
}

/** A normalized row for the admin money-ops screen (deposits + withdrawals). */
export interface AdminTxn {
  id: string;
  kind: 'deposit' | 'withdrawal';
  amount: number;
  currency: string;
  status: string;
  flagged: boolean;
  flagReason: string | null;
  method: string | null;
  note: string | null;
  reason: string | null;
  createdAt: string;
  user: { id: string; name: string; username: string; email: string | null };
}

const LEDGER_LABEL: Record<string, { kind: UserTxn['kind']; title: string }> = {
  deposit: { kind: 'deposit', title: 'Deposit' },
  withdrawal_hold: { kind: 'withdrawal', title: 'Withdrawal' },
  withdrawal_refund: { kind: 'withdrawal', title: 'Withdrawal refunded' },
  copy_allocate: { kind: 'transfer', title: 'Copy allocation' },
  copy_return: { kind: 'transfer', title: 'Copy principal returned' },
  trade_pnl: { kind: 'trade', title: 'Trade P/L' },
  commission: { kind: 'fee', title: 'Performance fee' },
  commission_earned: { kind: 'commission', title: 'Commission earned' },
  platform_fee: { kind: 'fee', title: 'Platform fee' },
  adjustment: { kind: 'transfer', title: 'Adjustment' },
};

@Injectable()
export class TransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The user's complete transaction timeline: every ledger movement plus any
   * deposits still pending (not yet in the ledger). Newest first.
   */
  async userTimeline(userId: string, limit = 50): Promise<UserTxn[]> {
    const [ledger, pendingDeposits] = await Promise.all([
      this.prisma.ledgerEntry.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
      this.prisma.deposit.findMany({
        where: { userId, status: DepositStatus.pending },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);

    const rows: UserTxn[] = ledger.map((l) => {
      const map = LEDGER_LABEL[l.type] ?? { kind: 'transfer' as const, title: l.type };
      return {
        id: l.id,
        kind: map.kind,
        title: l.note ?? map.title,
        amount: l.amount,
        currency: l.currency,
        status: 'completed',
        createdAt: l.createdAt.toISOString(),
      };
    });
    for (const d of pendingDeposits) {
      rows.push({
        id: d.id,
        kind: 'deposit',
        title: `Deposit ${d.asset ?? d.method}`,
        amount: d.amount,
        currency: d.currency,
        status: 'pending',
        createdAt: d.createdAt.toISOString(),
      });
    }
    rows.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    return rows.slice(0, limit);
  }

  /**
   * Admin money-ops view: deposits + withdrawals merged, newest first, with
   * optional filters. Cursor is a createdAt watermark (load-more).
   */
  async adminList(q: {
    kind?: 'deposit' | 'withdrawal';
    status?: string;
    flagged?: boolean;
    limit?: number;
    cursor?: string;
  }): Promise<{ items: AdminTxn[]; nextCursor: string | null }> {
    const limit = Math.min(100, q.limit ?? 30);
    const before = q.cursor ? new Date(Buffer.from(q.cursor, 'base64').toString('utf8')) : null;
    const dateWhere = before ? { createdAt: { lt: before } } : {};

    const wantDeposits = !q.kind || q.kind === 'deposit';
    const wantPayouts = !q.kind || q.kind === 'withdrawal';

    const [deposits, payouts] = await Promise.all([
      wantDeposits
        ? this.prisma.deposit.findMany({
            where: {
              ...dateWhere,
              ...(q.status ? { status: q.status as DepositStatus } : {}),
              ...(q.flagged !== undefined ? { flagged: q.flagged } : {}),
            },
            orderBy: { createdAt: 'desc' },
            take: limit + 1,
            include: { user: true },
          })
        : Promise.resolve([]),
      wantPayouts
        ? this.prisma.payout.findMany({
            where: {
              ...dateWhere,
              ...(q.status ? { status: q.status as any } : {}),
              ...(q.flagged !== undefined ? { flagged: q.flagged } : {}),
            },
            orderBy: { createdAt: 'desc' },
            take: limit + 1,
            include: { user: true },
          })
        : Promise.resolve([]),
    ]);

    const merged: AdminTxn[] = [
      ...deposits.map((d) => ({
        id: d.id,
        kind: 'deposit' as const,
        amount: d.amount,
        currency: d.currency,
        status: d.status,
        flagged: d.flagged,
        flagReason: d.flagReason,
        method: d.method,
        note: null,
        reason: d.reason,
        createdAt: d.createdAt.toISOString(),
        user: { id: d.user.id, name: d.user.name, username: d.user.username, email: d.user.email },
      })),
      ...payouts.map((p) => ({
        id: p.id,
        kind: 'withdrawal' as const,
        amount: p.amount,
        currency: p.currency,
        status: p.status,
        flagged: p.flagged,
        flagReason: p.flagReason,
        method: p.method,
        note: p.note,
        reason: p.reason,
        createdAt: p.createdAt.toISOString(),
        user: { id: p.user.id, name: p.user.name, username: p.user.username, email: p.user.email },
      })),
    ].sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));

    const page = merged.slice(0, limit);
    const hasMore = merged.length > limit;
    const nextCursor = hasMore
      ? Buffer.from(page[page.length - 1].createdAt).toString('base64')
      : null;
    return { items: page, nextCursor };
  }
}
