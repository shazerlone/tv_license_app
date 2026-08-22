import { BadRequestException, Injectable } from '@nestjs/common';
import { LedgerType, Prisma, Wallet } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';

const round2 = (n: number) => Math.round(n * 100) / 100;

export interface PostArgs {
  userId: string;
  type: LedgerType;
  /** Signed: credits positive, debits negative. */
  amount: number;
  refId?: string;
  note?: string;
  /** Allow the balance to go negative (only for admin adjustments). */
  allowNegative?: boolean;
  /** Run inside an existing interactive transaction when provided. */
  tx?: Prisma.TransactionClient;
}

/**
 * The Millimore wallet ledger. Every balance change goes through `post()`, which
 * updates the wallet and writes an append-only LedgerEntry in the same
 * transaction — so the books always reconcile. This is the internal accounting
 * layer; real crypto/broker rails plug in above it later (deposits/withdrawals),
 * never bypassing it.
 */
@Injectable()
export class WalletService {
  constructor(private readonly prisma: PrismaService) {}

  private client(tx?: Prisma.TransactionClient) {
    return tx ?? this.prisma;
  }

  async getOrCreate(userId: string, tx?: Prisma.TransactionClient): Promise<Wallet> {
    const db = this.client(tx);
    const existing = await db.wallet.findUnique({ where: { userId } });
    if (existing) return existing;
    return db.wallet.create({
      data: { id: genId('w'), userId, balance: 0, currency: 'USD' },
    });
  }

  async balance(userId: string): Promise<number> {
    const w = await this.prisma.wallet.findUnique({ where: { userId } });
    return w?.balance ?? 0;
  }

  /**
   * Apply a signed amount to a user's wallet and record the ledger row. Runs in
   * a transaction (its own, or a caller-provided one) to keep wallet + ledger
   * consistent. Returns the new balance.
   */
  async post(args: PostArgs): Promise<number> {
    const run = async (tx: Prisma.TransactionClient): Promise<number> => {
      const wallet = await this.getOrCreate(args.userId, tx);
      const next = round2(wallet.balance + args.amount);
      if (next < 0 && !args.allowNegative) {
        throw new BadRequestException({
          code: 'insufficient_balance',
          message: 'Insufficient wallet balance.',
        });
      }
      await tx.wallet.update({ where: { userId: args.userId }, data: { balance: next } });
      await tx.ledgerEntry.create({
        data: {
          id: genId('led'),
          userId: args.userId,
          type: args.type,
          amount: round2(args.amount),
          balanceAfter: next,
          currency: wallet.currency,
          refId: args.refId ?? null,
          note: args.note ?? null,
        },
      });
      return next;
    };

    if (args.tx) return run(args.tx);
    return this.prisma.$transaction(run);
  }

  async ledger(userId: string, limit = 50) {
    const rows = await this.prisma.ledgerEntry.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      id: r.id,
      type: r.type,
      amount: r.amount,
      balanceAfter: r.balanceAfter,
      currency: r.currency,
      refId: r.refId,
      note: r.note,
      createdAt: r.createdAt.toISOString(),
    }));
  }

  /** Lifetime commission a trader has earned (sum of commission_earned rows). */
  async lifetimeCommission(userId: string): Promise<number> {
    const agg = await this.prisma.ledgerEntry.aggregate({
      where: { userId, type: LedgerType.commission_earned },
      _sum: { amount: true },
    });
    return round2(agg._sum.amount ?? 0);
  }
}
