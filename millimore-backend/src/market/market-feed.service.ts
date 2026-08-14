import { Injectable, Logger } from '@nestjs/common';
import type { PriceMap } from './prices.service';

/**
 * Real market-data seam. Fetches live quotes from an external provider so the
 * price engine can anchor its ticks to reality. Gated entirely by env — with no
 * provider configured `enabled` is false and the engine keeps running purely
 * synthetically (dev/offline). Swap the provider (or drop in the MT bridge feed)
 * here without touching PricesService or the WS protocol.
 *
 * Providers (free tiers are rate-limited, so PricesService polls every ~15s and
 * interpolates between refreshes):
 *   - twelvedata: one batched /price call for all symbols  (TWELVE_DATA_API_KEY)
 *   - finnhub:    one /quote call per symbol                (FINNHUB_API_KEY)
 * Auto-selects by whichever key is present when MARKET_DATA_PROVIDER is unset.
 */
@Injectable()
export class MarketFeedService {
  private readonly logger = new Logger('MarketFeedService');
  private readonly configured: string;
  private readonly twelveKey?: string;
  private readonly finnhubKey?: string;
  private warned = false;

  // Our canonical symbol → each provider's symbol. Symbols absent from a map are
  // simply not fetched from that provider and keep their synthetic value.
  private static readonly TWELVE: Record<string, string> = {
    'XAU/USD': 'XAU/USD',
    'EUR/USD': 'EUR/USD',
    'GBP/USD': 'GBP/USD',
    'USD/JPY': 'USD/JPY',
    'AUD/USD': 'AUD/USD',
    'BTC/USD': 'BTC/USD',
    'ETH/USD': 'ETH/USD',
    'SOL/USD': 'SOL/USD',
    US30: 'DJI',
    NAS100: 'NDX',
    US500: 'SPX',
  };
  private static readonly FINNHUB: Record<string, string> = {
    'XAU/USD': 'OANDA:XAU_USD',
    'EUR/USD': 'OANDA:EUR_USD',
    'GBP/USD': 'OANDA:GBP_USD',
    'USD/JPY': 'OANDA:USD_JPY',
    'AUD/USD': 'OANDA:AUD_USD',
    'BTC/USD': 'BINANCE:BTCUSDT',
    'ETH/USD': 'BINANCE:ETHUSDT',
    'SOL/USD': 'BINANCE:SOLUSDT',
  };

  constructor() {
    this.configured = (process.env.MARKET_DATA_PROVIDER ?? '').trim().toLowerCase();
    this.twelveKey = process.env.TWELVE_DATA_API_KEY?.trim() || undefined;
    this.finnhubKey = process.env.FINNHUB_API_KEY?.trim() || undefined;
  }

  /** Which provider will actually be used, or null when none is available. */
  private resolve(): 'twelvedata' | 'finnhub' | null {
    if (this.configured === 'twelvedata') return this.twelveKey ? 'twelvedata' : null;
    if (this.configured === 'finnhub') return this.finnhubKey ? 'finnhub' : null;
    if (this.configured && this.configured !== 'auto' && this.configured !== 'none') return null;
    if (this.configured === 'none') return null;
    // auto / unset: prefer the batched provider.
    if (this.twelveKey) return 'twelvedata';
    if (this.finnhubKey) return 'finnhub';
    return null;
  }

  get enabled(): boolean {
    return this.resolve() !== null;
  }

  get providerName(): string {
    return this.resolve() ?? 'synthetic';
  }

  /** Fetch live prices for the resolvable subset of `symbols`. Never throws. */
  async fetchQuotes(symbols: string[]): Promise<PriceMap> {
    const provider = this.resolve();
    try {
      if (provider === 'twelvedata') return await this.fetchTwelve(symbols);
      if (provider === 'finnhub') return await this.fetchFinnhub(symbols);
    } catch (err) {
      if (!this.warned) {
        this.warned = true;
        this.logger.warn(`market feed (${provider}) failed, holding synthetic: ${String(err)}`);
      }
    }
    return {};
  }

  private async fetchTwelve(symbols: string[]): Promise<PriceMap> {
    const ours = symbols.filter((s) => MarketFeedService.TWELVE[s]);
    if (ours.length === 0) return {};
    const provToOurs = new Map<string, string>();
    for (const s of ours) provToOurs.set(MarketFeedService.TWELVE[s], s);
    const list = ours.map((s) => MarketFeedService.TWELVE[s]).join(',');
    const url = `https://api.twelvedata.com/price?symbol=${encodeURIComponent(list)}&apikey=${this.twelveKey}`;
    const json = (await this.getJson(url)) as Record<string, unknown>;

    const out: PriceMap = {};
    // Single symbol → { price: "1.08" }; multiple → { "EUR/USD": { price: "1.08" }, … }.
    if (typeof json.price === 'string' && ours.length === 1) {
      const v = Number(json.price);
      if (Number.isFinite(v)) out[ours[0]] = v;
      return out;
    }
    for (const [prov, node] of Object.entries(json)) {
      const mine = provToOurs.get(prov);
      const priceStr = (node as { price?: string } | null)?.price;
      const v = priceStr != null ? Number(priceStr) : NaN;
      if (mine && Number.isFinite(v)) out[mine] = v;
    }
    return out;
  }

  private async fetchFinnhub(symbols: string[]): Promise<PriceMap> {
    const ours = symbols.filter((s) => MarketFeedService.FINNHUB[s]);
    if (ours.length === 0) return {};
    const out: PriceMap = {};
    await Promise.all(
      ours.map(async (s) => {
        const url = `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(
          MarketFeedService.FINNHUB[s],
        )}&token=${this.finnhubKey}`;
        try {
          const json = (await this.getJson(url)) as { c?: number };
          if (typeof json.c === 'number' && json.c > 0) out[s] = json.c;
        } catch {
          /* leave this symbol synthetic */
        }
      }),
    );
    return out;
  }

  private async getJson(url: string): Promise<unknown> {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    try {
      const res = await fetch(url, { signal: controller.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } finally {
      clearTimeout(t);
    }
  }
}
