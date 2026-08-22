/**
 * MT bridge — the single seam between Millimore and a real MT4/MT5 backend
 * (contract §8, §9.6). Everything trading-related that must eventually become
 * "real" goes through this interface, so switching from synthetic data to a
 * live provider (MetaAPI.cloud or a custom EA gateway) is a config change, not
 * a rewrite. Nothing outside this module may import a provider directly.
 */

export const MT_BRIDGE = Symbol('MT_BRIDGE');

export type MtBridgeMode = 'synthetic' | 'live';

/** Live-ish account snapshot for a connected trading account. */
export interface MtAccountInfo {
  balance: number;
  equity: number;
  currency: string;
  /** true only when a live provider actually reached the broker. */
  live: boolean;
}

/** Result of checking an investor (read-only) password against a broker server. */
export interface MtVerifyResult {
  ok: boolean;
  reason?: string;
}

/** A single price tick the engine can publish on the `prices` channel. */
export interface MtPrice {
  symbol: string;
  price: number;
  ts: number;
}

/** An order request placed on-stream or by the copy engine. */
export interface MtOrderRequest {
  accountRef: string; // opaque per-provider account handle
  symbol: string;
  side: 'buy' | 'sell';
  volume: number; // lots
}

export interface MtOrderResult {
  ok: boolean;
  orderId?: string;
  reason?: string;
}

export interface MtBridge {
  /** Which implementation is active — surfaced in admin metrics. */
  readonly mode: MtBridgeMode;

  /**
   * Verify an investor password for a broker account. Synthetic mode accepts
   * any non-empty password; a live provider actually logs in read-only.
   */
  verifyInvestorPassword(input: {
    platform: string;
    server: string;
    account: string;
    investorPassword: string;
  }): Promise<MtVerifyResult>;

  /** Balance/equity for a connected account. */
  getAccountInfo(input: {
    platform?: string;
    server?: string;
    account: string;
  }): Promise<MtAccountInfo>;

  /** Place an order (live orders / on-stream execution). */
  placeOrder(req: MtOrderRequest): Promise<MtOrderResult>;
}
