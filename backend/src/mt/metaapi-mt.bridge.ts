import { Injectable, Logger } from '@nestjs/common';
import {
  MtAccountInfo,
  MtBridge,
  MtOrderRequest,
  MtOrderResult,
  MtVerifyResult,
} from './mt.types';

/**
 * Live MT bridge — activated when BROKER_BRIDGE_URL (+ BROKER_BRIDGE_TOKEN) is
 * set. Talks to a hosted MT4/MT5 gateway (MetaAPI.cloud or a custom EA bridge)
 * over HTTPS. Implemented against the same MtBridge interface so callers never
 * change. The HTTP calls are intentionally thin and defensive: any failure
 * degrades to a clear error rather than crashing the request path.
 *
 * NOTE: exact request/response shapes depend on the chosen provider; the
 * endpoints below are the integration seam to fill in when a provider account
 * exists. Until then this class is only constructed if the env vars are present.
 */
@Injectable()
export class MetaApiMtBridge implements MtBridge {
  readonly mode = 'live' as const;
  private readonly log = new Logger('MtBridge:live');

  constructor(
    private readonly baseUrl: string,
    private readonly token: string | undefined,
  ) {}

  private async call<T>(path: string, body: unknown): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(this.token ? { authorization: `Bearer ${this.token}` } : {}),
      },
      body: JSON.stringify(body),
      // Never let the bridge hang a request forever.
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) {
      throw new Error(`bridge ${path} -> ${res.status}`);
    }
    return (await res.json()) as T;
  }

  async verifyInvestorPassword(input: {
    platform: string;
    server: string;
    account: string;
    investorPassword: string;
  }): Promise<MtVerifyResult> {
    try {
      return await this.call<MtVerifyResult>('/verify', input);
    } catch (e) {
      this.log.warn(`verify failed: ${(e as Error).message}`);
      return { ok: false, reason: 'bridge_unreachable' };
    }
  }

  async getAccountInfo(input: {
    platform?: string;
    server?: string;
    account: string;
  }): Promise<MtAccountInfo> {
    const r = await this.call<Omit<MtAccountInfo, 'live'>>('/account', input);
    return { ...r, live: true };
  }

  async placeOrder(req: MtOrderRequest): Promise<MtOrderResult> {
    try {
      return await this.call<MtOrderResult>('/order', req);
    } catch (e) {
      this.log.warn(`order failed: ${(e as Error).message}`);
      return { ok: false, reason: 'bridge_unreachable' };
    }
  }
}
