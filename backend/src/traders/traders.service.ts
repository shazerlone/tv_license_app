import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Trader } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { encodeCursor, decodeCursor, Paginated } from '../common/dto/pagination.dto';
import { seedFromString, mulberry32, round } from '../common/rng';
import { genId } from '../common/ids';
import {
  TraderDto,
  TradersQueryDto,
  PublicTradeDto,
  EquityPointDto,
} from './dto/trader.dto';

const PAIRS: Record<string, string[]> = {
  Forex: ['EUR/USD', 'GBP/USD', 'USD/JPY', 'AUD/USD'],
  Crypto: ['BTC/USD', 'ETH/USD', 'SOL/USD'],
  Gold: ['XAU/USD'],
  Indices: ['US30', 'NAS100', 'US500'],
};

@Injectable()
export class TradersService {
  constructor(private readonly prisma: PrismaService) {}

  toDto(t: Trader): TraderDto {
    return {
      id: t.id,
      name: t.name,
      username: t.username,
      photoUrl: t.photoUrl,
      isVerified: t.isVerified,
      isLive: t.isLive,
      returnPercent: t.returnPercent,
      returnDays: t.returnDays,
      followers: t.followers,
      copiers: t.copiers,
      aum: t.aum,
      winRate: t.winRate,
      maxDrawdown: t.maxDrawdown,
      totalTrades: t.totalTrades,
      commissionPercent: t.commissionPercent,
      category: t.category,
      tags: t.tags,
      bio: t.bio,
    };
  }

  async list(q: TradersQueryDto): Promise<Paginated<TraderDto>> {
    const limit = q.limit ?? 20;
    const where: Prisma.TraderWhereInput = {};
    if (q.category) where.category = q.category;
    if (q.q) {
      where.OR = [
        { name: { contains: q.q, mode: 'insensitive' } },
        { username: { contains: q.q, mode: 'insensitive' } },
      ];
    }

    const orderBy: Prisma.TraderOrderByWithRelationInput[] =
      q.sort === 'return'
        ? [{ returnPercent: 'desc' }, { id: 'asc' }]
        : [{ copiers: 'desc' }, { id: 'asc' }];

    const cursorId = decodeCursor(q.cursor);
    const rows = await this.prisma.trader.findMany({
      where,
      orderBy,
      take: limit + 1,
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
    });

    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit);
    return {
      items: items.map((t) => this.toDto(t)),
      nextCursor: hasMore ? encodeCursor(items[items.length - 1].id) : null,
    };
  }

  async getEntityOrThrow(id: string): Promise<Trader> {
    const t = await this.prisma.trader.findUnique({ where: { id } });
    if (!t) throw new NotFoundException({ code: 'trader_not_found', message: 'Trader not found' });
    return t;
  }

  async getOne(id: string): Promise<TraderDto> {
    return this.toDto(await this.getEntityOrThrow(id));
  }

  async liveTraders(): Promise<Trader[]> {
    return this.prisma.trader.findMany({ where: { isLive: true }, orderBy: { copiers: 'desc' } });
  }

  /**
   * Ensure a User has a public Trader profile. Called when a creator is approved
   * and when they first compose — so approved creators appear in GET /traders
   * immediately (with zeroed stats), even before any trading activity.
   */
  async ensureForUser(userId: string): Promise<Trader> {
    const existing = await this.prisma.trader.findUnique({ where: { userId } });
    if (existing) return existing;
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    return this.prisma.trader.create({
      data: {
        id: genId('t'),
        userId: user.id,
        name: user.name,
        username: user.username,
        photoUrl: user.photoUrl,
        isVerified: user.creatorStatus === 'approved',
        category: user.market ?? 'Forex',
      },
    });
  }

  // ── synthetic (until the real trade feed lands) ─────────────────────

  async equity(id: string, range = '30d'): Promise<EquityPointDto[]> {
    const trader = await this.getEntityOrThrow(id);
    const days = this.rangeToDays(range);
    const rnd = mulberry32(seedFromString(`${trader.id}:equity:${days}`));
    const start = 10000;
    const end = start * (1 + trader.returnPercent / 100);
    const drift = (end - start) / days;

    const points: EquityPointDto[] = [];
    let value = start;
    const now = Date.now();
    for (let i = days; i >= 0; i--) {
      const noise = (rnd() - 0.5) * start * 0.012; // ~±1.2% daily wobble
      value = i === 0 ? end : value + drift + noise;
      points.push({
        t: new Date(now - i * 86400000).toISOString(),
        value: round(value),
      });
    }
    return points;
  }

  async trades(id: string, status?: 'active' | 'closed'): Promise<PublicTradeDto[]> {
    const trader = await this.getEntityOrThrow(id);
    const pairs = PAIRS[trader.category] ?? PAIRS.Forex;
    const rnd = mulberry32(seedFromString(`${trader.id}:trades`));
    const out: PublicTradeDto[] = [];
    const now = Date.now();

    const make = (i: number, isClosed: boolean): PublicTradeDto => {
      const pair = pairs[Math.floor(rnd() * pairs.length)];
      const isBuy = rnd() > 0.45;
      const base = pair.includes('JPY') ? 150 : pair === 'XAU/USD' ? 2000 : pair.includes('/USD') && pair.length <= 7 ? 1.08 : 34000;
      const entryPrice = round(base * (1 + (rnd() - 0.5) * 0.02), base < 10 ? 4 : 2);
      const win = rnd() < trader.winRate / 100;
      const move = (win ? 1 : -1) * (0.2 + rnd() * 1.3);
      const pnlPercent = round((isBuy ? 1 : 1) * move, 2);
      const lots = round(0.05 + rnd() * 0.9, 2);
      const pnlAmount = round(pnlPercent * lots * 100, 2);
      const openedAt = new Date(now - (i + 1) * 3600_000 * (isClosed ? 6 : 2)).toISOString();
      return {
        id: `ptr_${trader.id}_${isClosed ? 'c' : 'a'}${i}`,
        traderId: trader.id,
        traderName: trader.name,
        pair,
        isBuy,
        status: isClosed ? 'closed' : 'active',
        entryPrice,
        exitPrice: isClosed ? round(entryPrice * (1 + move / 100), base < 10 ? 4 : 2) : null,
        pnlAmount,
        pnlPercent,
        lots,
        openedAt,
        closedAt: isClosed ? new Date(now - i * 3600_000 * 5).toISOString() : null,
      };
    };

    if (status !== 'closed') for (let i = 0; i < 4; i++) out.push(make(i, false));
    if (status !== 'active') for (let i = 0; i < 8; i++) out.push(make(i, true));
    return out;
  }

  private rangeToDays(range: string): number {
    const m = /^(\d+)\s*d$/i.exec(range.trim());
    if (m) return Math.min(365, Math.max(1, Number(m[1])));
    if (/^1y$/i.test(range)) return 365;
    return 30;
  }
}
