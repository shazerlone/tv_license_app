import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { EventEmitter } from 'events';

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

/**
 * In-memory market price engine. Ticks ~1/sec with a small random walk and
 * emits the full snapshot on the `tick` event. Backed by synthetic data now;
 * swap the tick source for the MT bridge / MetaApi feed (milestone 6) without
 * changing consumers. For multi-instance scale, publish ticks to Redis and have
 * each instance's WS gateway subscribe (see ARCHITECTURE.md).
 */
@Injectable()
export class PricesService extends EventEmitter implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('PricesService');
  private prices: PriceMap = {};
  private timer?: NodeJS.Timeout;

  onModuleInit() {
    for (const [sym, cfg] of Object.entries(SYMBOLS)) {
      this.prices[sym] = cfg.base;
    }
    this.timer = setInterval(() => this.tick(), 1000);
    // Node keeps the process alive only while there are listeners; the interval
    // is fine. Don't block shutdown:
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.removeAllListeners();
  }

  private tick() {
    for (const [sym, cfg] of Object.entries(SYMBOLS)) {
      const drift = (Math.random() - 0.5) * 2 * cfg.vol; // ±vol
      const next = this.prices[sym] * (1 + drift);
      this.prices[sym] = this.round(next, cfg.dp);
    }
    this.emit('tick', this.snapshot());
  }

  private round(n: number, dp: number): number {
    const f = 10 ** dp;
    return Math.round(n * f) / f;
  }

  symbols(): string[] {
    return Object.keys(SYMBOLS);
  }

  /** Snapshot of all (or a subset of) current prices. */
  snapshot(only?: string[]): PriceMap {
    if (!only || only.length === 0) return { ...this.prices };
    const out: PriceMap = {};
    for (const s of only) if (this.prices[s] != null) out[s] = this.prices[s];
    return out;
  }

  price(symbol: string): number | undefined {
    return this.prices[symbol];
  }
}
