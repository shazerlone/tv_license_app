import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { EventEmitter } from 'events';
import { randomBytes } from 'crypto';
import { RedisService } from '../redis/redis.service';

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

/**
 * Market price engine. Ticks ~1/sec and emits the snapshot on `tick`.
 *
 * Multi-instance (Redis enabled): a single elected leader generates ticks and
 * publishes them; every instance subscribes and emits the same snapshot, so all
 * clients see identical prices regardless of which instance they're on.
 * Single-instance (no Redis): generates and emits locally.
 *
 * Synthetic now → swap the generator for the MT bridge / MetaApi feed (milestone
 * 6) with no change to consumers or the WS protocol.
 */
@Injectable()
export class PricesService extends EventEmitter implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('PricesService');
  private readonly instanceId = randomBytes(6).toString('hex');
  private prices: PriceMap = {};
  private timer?: NodeJS.Timeout;

  constructor(private readonly redis: RedisService) {
    super();
    this.setMaxListeners(0);
  }

  async onModuleInit() {
    for (const [sym, cfg] of Object.entries(SYMBOLS)) this.prices[sym] = cfg.base;

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
      const next = this.generate(this.prices);
      await this.redis.set(KEY_SNAPSHOT, JSON.stringify(next));
      await this.redis.publish(CH_PRICES, next); // sub handler applies + emits everywhere
      return;
    }
    // Single-instance: generate and emit directly.
    this.prices = this.generate(this.prices);
    this.emit('tick', this.prices);
  }

  private generate(from: PriceMap): PriceMap {
    const out: PriceMap = {};
    for (const [sym, cfg] of Object.entries(SYMBOLS)) {
      const cur = from[sym] ?? cfg.base;
      const drift = (Math.random() - 0.5) * 2 * cfg.vol;
      out[sym] = this.round(cur * (1 + drift), cfg.dp);
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
