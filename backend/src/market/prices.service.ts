import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { EventEmitter } from 'events';
import { randomBytes } from 'crypto';
import { PositionStatus } from '@prisma/client';
import { RedisService } from '../redis/redis.service';
import { PrismaService } from '../prisma/prisma.service';
import { MarketFeedService } from './market-feed.service';

export type PriceMap = Record<string, number>;

/** Base prices + decimal precision per symbol. */
const SYMBOLS: Record<string, { base: number; dp: number; vol: number }> = {
  'XAU/USD': { base: 2015.3, dp: 2, vol: 0.0006 },
  'EUR/USD': { base: 1.0851, dp: 4, vol: 0.0004 },
  'GBP/USD': { base: 1.2712, dp: 4, vol: 0.0004 },
  'USD/JPY': { base: 151.24, dp: 3, vol: 0.0004 },
  'AUD/USD': { base: 0.6612, dp: 4, vol: 0.0005 },
  'BTC/USD': { base: 67250, dp: 1, vol: 0.0012 },
  'ETH/USD': { base: 3520, dp: 2, vol: 0.0015 },
  'SOL/USD': { base: 168.4, dp: 2, vol: 0.002 },
  US30: { base: 39120, dp: 1, vol: 0.0005 },
  NAS100: { base: 18240, dp: 1, vol: 0.0006 },
  US500: { base: 5240, dp: 1, vol: 0.0005 },
};

const CH_PRICES = 'rt:prices';
const KEY_SNAPSHOT = 'prices:snapshot';
const KEY_LEADER = 'prices:leader';
const LEADER_TTL_MS = 3000;
// Per-tick pull of the live price toward its real anchor (0..1).
const REVERSION = 0.25;

const num = (v: string | undefined, d: number) => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : d;
};
// How often the leader pulls fresh real quotes. Providers bill 1 credit per
// symbol per call, so this × (active symbols) × 1440 = credits/day — keep it high.
const REFRESH_MS = num(process.env.MARKET_REFRESH_MS, 60_000);
// A symbol counts as "in use" for this long after it's requested via REST.
const ACTIVE_WINDOW_MS = num(process.env.MARKET_ACTIVE_WINDOW_MS, 180_000);
// Hard daily cap on provider credits (symbols fetched). Once hit, we hold the
// last real anchors (synthetic interpolation continues) until the UTC-day reset.
// Prevents ever blowing a metered plan again, whatever the load.
const DAILY_CREDIT_BUDGET = num(process.env.MARKET_DAILY_CREDIT_BUDGET, 750);

/**
 * Market price engine. Ticks ~1/sec and emits the snapshot on `tick`.
 *
 * Multi-instance (Redis enabled): a single elected leader generates ticks and
 * publishes them; every instance subscribes and emits the same snapshot, so all
 * clients see identical prices regardless of which instance they're on.
 * Single-instance (no Redis): generates and emits locally.
 *
 * Real feed (MarketFeedService) anchors the ticks to live provider quotes when a
 * provider is configured; otherwise anchors stay at the built-in bases and the
 * engine is fully synthetic. Either way consumers and the WS protocol are
 * unchanged — the MT bridge / MetaApi feed can later replace MarketFeedService.
 */
@Injectable()
export class PricesService extends EventEmitter implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('PricesService');
  private readonly instanceId = randomBytes(6).toString('hex');
  private prices: PriceMap = {};
  // Real-world targets each tick reverts toward. Default to the synthetic bases.
  private anchors: PriceMap = {};
  private lastRefresh = 0;
  // symbol → epoch-ms until which a REST-requested symbol stays "in use".
  private activeUntil = new Map<string, number>();
  // Daily credit accounting (UTC day) for the hard budget guard.
  private creditDay = '';
  private creditsUsedToday = 0;
  private budgetWarned = false;
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
    private readonly feed: MarketFeedService,
  ) {
    super();
    this.setMaxListeners(0);
  }

  /** Mark symbols as actively viewed (from GET /prices) so the leader refreshes
   *  their real quotes for the next ACTIVE_WINDOW_MS. */
  markActive(symbols: string[]) {
    const until = Date.now() + ACTIVE_WINDOW_MS;
    for (const s of symbols) if (SYMBOLS[s]) this.activeUntil.set(s, until);
  }

  async onModuleInit() {
    for (const [sym, cfg] of Object.entries(SYMBOLS)) {
      this.prices[sym] = cfg.base;
      this.anchors[sym] = cfg.base;
    }

    if (this.feed.enabled) {
      this.logger.log(
        `market feed: ${this.feed.providerName} · refresh ${REFRESH_MS / 1000}s · active-only · budget ${DAILY_CREDIT_BUDGET} credits/day`,
      );
      // Prime real anchors immediately so prices are correct from the first tick.
      await this.refreshAnchors();
    } else {
      this.logger.log('market feed: synthetic (no provider configured)');
    }

    if (this.redis.enabled) {
      // Prime from the last shared snapshot so a fresh instance is correct now.
      const snap = await this.redis.get(KEY_SNAPSHOT);
      if (snap) {
        try {
          this.prices = { ...this.prices, ...JSON.parse(snap) };
        } catch {
          /* ignore */
        }
      }
      // Every instance applies leader-published ticks.
      await this.redis.subscribe(CH_PRICES, (snapshot: PriceMap) => {
        this.prices = snapshot;
        this.emit('tick', snapshot);
      });
    }

    this.timer = setInterval(() => void this.tick(), 1000);
    this.timer.unref?.();
  }

  private async tick() {
    if (this.redis.enabled) {
      // Only the elected leader generates + publishes; others just consume.
      const leader = await this.redis.acquireLeader(KEY_LEADER, this.instanceId, LEADER_TTL_MS);
      if (!leader) return;
      this.maybeRefresh();
      const next = this.generate(this.prices);
      await this.redis.set(KEY_SNAPSHOT, JSON.stringify(next));
      await this.redis.publish(CH_PRICES, next); // sub handler applies + emits everywhere
      return;
    }
    // Single-instance: generate and emit directly.
    this.maybeRefresh();
    this.prices = this.generate(this.prices);
    this.emit('tick', this.prices);
  }

  /** Kick off a real-quote refresh if the interval has elapsed (non-blocking). */
  private maybeRefresh() {
    if (!this.feed.enabled) return;
    const now = Date.now();
    if (now - this.lastRefresh < REFRESH_MS) return;
    this.lastRefresh = now;
    void this.refreshAnchors();
  }

  /**
   * The symbols worth spending real quotes on right now: those actively viewed
   * (GET /prices within the window) plus those the server needs regardless of
   * viewers — open copy positions (P/L) and active price alerts (triggers).
   * Everything else keeps drifting synthetically. Returns [] when nothing is in
   * use, so an idle server spends zero credits.
   */
  private async neededSymbols(): Promise<string[]> {
    const now = Date.now();
    const set = new Set<string>();
    for (const [sym, until] of this.activeUntil) {
      if (until > now) set.add(sym);
      else this.activeUntil.delete(sym);
    }
    try {
      const [positions, alerts] = await Promise.all([
        this.prisma.copyPosition.findMany({ where: { status: PositionStatus.active }, select: { pair: true }, distinct: ['pair'] }),
        this.prisma.priceAlert.findMany({ where: { status: 'active' }, select: { symbol: true }, distinct: ['symbol'] }),
      ]);
      for (const p of positions) if (p.pair) set.add(p.pair);
      for (const a of alerts) if (a.symbol) set.add(a.symbol);
    } catch {
      /* transient DB issue — fall back to just the actively-viewed set */
    }
    return [...set].filter((s) => SYMBOLS[s]);
  }

  /**
   * Pull live quotes for the in-use symbols only, in one batched request, within
   * the daily credit budget. Unfetched symbols keep their last anchor.
   */
  private async refreshAnchors() {
    const needed = await this.neededSymbols();
    if (needed.length === 0) return; // idle → no provider calls, no credits

    const day = new Date().toISOString().slice(0, 10);
    if (day !== this.creditDay) {
      this.creditDay = day;
      this.creditsUsedToday = 0;
      this.budgetWarned = false;
    }
    const remaining = DAILY_CREDIT_BUDGET - this.creditsUsedToday;
    if (remaining <= 0) {
      if (!this.budgetWarned) {
        this.budgetWarned = true;
        this.logger.warn(`market data daily credit budget (${DAILY_CREDIT_BUDGET}) reached — holding last quotes until UTC reset`);
      }
      return;
    }

    const batch = needed.slice(0, remaining); // never spend past the budget
    const quotes = await this.feed.fetchQuotes(batch);
    this.creditsUsedToday += batch.length; // providers bill per requested symbol
    for (const sym of batch) {
      const q = quotes[sym];
      const cfg = SYMBOLS[sym];
      if (cfg && q != null && Number.isFinite(q)) this.anchors[sym] = this.round(q, cfg.dp);
    }
  }

  private generate(from: PriceMap): PriceMap {
    const out: PriceMap = {};
    for (const [sym, cfg] of Object.entries(SYMBOLS)) {
      const cur = from[sym] ?? cfg.base;
      const anchor = this.anchors[sym] ?? cfg.base;
      // Reversion toward the real (or base) anchor + small volatility jitter, so
      // prices track reality between refreshes while still ticking every second.
      const revert = (anchor - cur) * REVERSION;
      const jitter = (Math.random() - 0.5) * 2 * cfg.vol * cur;
      out[sym] = this.round(cur + revert + jitter, cfg.dp);
    }
    return out;
  }

  private round(n: number, dp: number): number {
    const f = 10 ** dp;
    return Math.round(n * f) / f;
  }

  symbols(): string[] {
    return Object.keys(SYMBOLS);
  }

  snapshot(only?: string[]): PriceMap {
    if (!only || only.length === 0) return { ...this.prices };
    const out: PriceMap = {};
    for (const s of only) if (this.prices[s] != null) out[s] = this.prices[s];
    return out;
  }

  price(symbol: string): number | undefined {
    return this.prices[symbol];
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.removeAllListeners();
  }
}
