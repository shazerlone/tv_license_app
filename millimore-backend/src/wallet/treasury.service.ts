import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoAddressService } from './crypto/crypto-address.service';
import { SweepService } from './crypto/sweep.service';
import { DepositNetwork, DEPOSIT_NETWORKS } from './crypto/address-provider';

/**
 * Crypto treasury tracker for the admin panel: how much has been deposited across
 * all per-user addresses, how much has been swept (consolidated) to the master, and
 * how much is still sitting unswept — plus per-address status so nothing is missed.
 *
 * The default numbers are ledger-derived (cheap, from our DB: confirmed deposits
 * minus successful sweeps). An explicit on-chain reconcile reads live balances from
 * the chain for the truth (used sparingly — one provider call per address).
 */
@Injectable()
export class TreasuryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly addresses: CryptoAddressService,
    private readonly sweep: SweepService,
  ) {}

  /** Portfolio-wide totals + per-network breakdown (ledger view). */
  async summary() {
    const [addrCount, addrByNet, depAgg, depByNet, sweptAgg, sweptByNet, failedCount, pendingCount] = await Promise.all([
      this.prisma.depositAddress.count(),
      this.prisma.depositAddress.groupBy({ by: ['network'], _count: { _all: true } }),
      this.prisma.deposit.aggregate({ _sum: { amount: true }, where: { status: 'confirmed', method: 'crypto' } }),
      this.prisma.deposit.groupBy({ by: ['payCurrency'], _sum: { amount: true }, where: { status: 'confirmed', method: 'crypto' } }),
      this.prisma.sweep.aggregate({ _sum: { amount: true }, where: { status: { in: ['broadcast', 'confirmed'] } } }),
      this.prisma.sweep.groupBy({ by: ['network'], _sum: { amount: true }, where: { status: { in: ['broadcast', 'confirmed'] } } }),
      this.prisma.sweep.count({ where: { status: 'failed' } }),
      this.prisma.sweep.count({ where: { status: { in: ['pending', 'broadcast'] } } }),
    ]);

    const deposited = round2(depAgg._sum.amount ?? 0);
    const swept = round2(sweptAgg._sum.amount ?? 0);
    const unswept = round2(Math.max(0, deposited - swept));

    const depNet = new Map(depByNet.map((r) => [r.payCurrency ?? '', r._sum.amount ?? 0]));
    const sweptNet = new Map(sweptByNet.map((r) => [r.network, r._sum.amount ?? 0]));
    const addrNet = new Map(addrByNet.map((r) => [r.network, r._count._all]));
    const byNetwork = DEPOSIT_NETWORKS.map((n) => {
      const dep = round2(depNet.get(n) ?? 0);
      const sw = round2(sweptNet.get(n) ?? 0);
      return { network: n, addresses: addrNet.get(n) ?? 0, deposited: dep, swept: sw, unswept: round2(Math.max(0, dep - sw)) };
    });

    return {
      addresses: addrCount,
      totals: { deposited, swept, unswept, currency: 'USDT' },
      sweeps: { pending: pendingCount, failed: failedCount },
      byNetwork,
      // So the panel can show whether auto-consolidation is even running.
      sweepConfig: {
        active: this.sweep.enabled,
        mode: this.sweep.mode,
      },
    };
  }

  /**
   * Per-address rows with deposited / swept / unswept and the latest sweep status.
   * Paginated by DepositAddress id. `filter`: 'unswept' (has funds waiting) |
   * 'failed' (last sweep failed) | 'all'.
   */
  async addresses_(query: { limit?: number; cursor?: string; network?: string; filter?: string }) {
    const limit = Math.min(Math.max(query.limit ?? 25, 1), 100);
    const where: Record<string, unknown> = {};
    if (query.network) where.network = query.network;
    const rows = await this.prisma.depositAddress.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, limit);
    const addrList = page.map((r) => r.address);

    // Aggregate deposits + latest deposit time per address on this page.
    const [depGroups, sweepRows, userRows] = await Promise.all([
      this.prisma.deposit.groupBy({
        by: ['address'],
        where: { address: { in: addrList }, status: 'confirmed', method: 'crypto' },
        _sum: { amount: true },
        _max: { createdAt: true },
      }),
      this.prisma.sweep.findMany({
        where: { fromAddress: { in: addrList } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.user.findMany({ where: { id: { in: page.map((r) => r.userId) } }, select: { id: true, username: true, name: true } }),
    ]);

    const depMap = new Map(depGroups.map((g) => [g.address ?? '', { deposited: g._sum.amount ?? 0, lastAt: g._max.createdAt }]));
    const sweptMap = new Map<string, number>();
    const lastSweep = new Map<string, (typeof sweepRows)[number]>();
    for (const s of sweepRows) {
      if (['broadcast', 'confirmed'].includes(s.status)) sweptMap.set(s.fromAddress, (sweptMap.get(s.fromAddress) ?? 0) + s.amount);
      if (!lastSweep.has(s.fromAddress)) lastSweep.set(s.fromAddress, s); // rows are desc, first = latest
    }
    const userMap = new Map(userRows.map((u) => [u.id, u]));

    let items = page.map((r) => {
      const dep = round2(depMap.get(r.address)?.deposited ?? 0);
      const swept = round2(sweptMap.get(r.address) ?? 0);
      const last = lastSweep.get(r.address);
      const u = userMap.get(r.userId);
      return {
        id: r.id,
        userId: r.userId,
        user: u ? { username: u.username, name: u.name } : null,
        network: r.network,
        address: r.address,
        deposited: dep,
        swept,
        unswept: round2(Math.max(0, dep - swept)),
        lastDepositAt: depMap.get(r.address)?.lastAt ?? null,
        lastSweep: last ? { status: last.status, at: last.createdAt, txRef: last.txRef, error: last.error } : null,
      };
    });

    if (query.filter === 'unswept') items = items.filter((i) => i.unswept > 0);
    else if (query.filter === 'failed') items = items.filter((i) => i.lastSweep?.status === 'failed');

    const nextCursor = rows.length > limit ? page[page.length - 1]?.id ?? null : null;
    return { items, nextCursor };
  }

  /** Recent sweep audit trail. */
  async sweeps(query: { limit?: number; status?: string }) {
    const limit = Math.min(Math.max(query.limit ?? 25, 1), 100);
    const where = query.status ? { status: query.status } : {};
    const rows = await this.prisma.sweep.findMany({ where, orderBy: { createdAt: 'desc' }, take: limit });
    return { items: rows };
  }

  /** Live on-chain USDT balance for up to `limit` funded addresses (the truth).
   *  Used by an explicit "Reconcile" action — one provider call per address. */
  async reconcile(limit = 50) {
    const funded = await this.prisma.deposit.findMany({
      where: { status: 'confirmed', method: 'crypto', address: { not: null } },
      distinct: ['address'],
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { address: true, payCurrency: true },
    });
    let onChainTotal = 0;
    const rows: Array<Record<string, unknown>> = [];
    for (const d of funded) {
      const network = (d.payCurrency ?? '') as DepositNetwork;
      if (!d.address || !network) continue;
      const { balance } = await this.addresses.usdtBalance(d.address, network);
      onChainTotal += balance;
      rows.push({ network, address: d.address, onChainBalance: round2(balance) });
    }
    return { checked: rows.length, onChainUnswept: round2(onChainTotal), currency: 'USDT', rows };
  }

  /** Manually run a consolidation batch now (admin "Sweep now"). */
  async sweepNow() {
    return this.sweep.sweepBatch();
  }

  /** Sweep a single address by its DepositAddress id. */
  async sweepOne(addressId: string) {
    const a = await this.prisma.depositAddress.findUnique({ where: { id: addressId } });
    if (!a) return { status: 'skipped', reason: 'address not found' };
    return this.sweep.sweepAddress(a.userId, a.network as DepositNetwork, a.address);
  }
}

const round2 = (n: number) => Math.round(n * 100) / 100;
