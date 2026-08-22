import { Injectable, Logger } from '@nestjs/common';
import {
  MtAccountInfo,
  MtBridge,
  MtOrderRequest,
  MtOrderResult,
  MtVerifyResult,
} from './mt.types';

/**
 * Default MT bridge used until a live provider is configured. Values are
 * deterministic per account (stable across restarts and across instances) so
 * the app renders consistent numbers — the same contract shape a live provider
 * will return, just synthesized. `live: false` marks the data as simulated.
 */
@Injectable()
export class SyntheticMtBridge implements MtBridge {
  readonly mode = 'synthetic' as const;
  private readonly log = new Logger('MtBridge:synthetic');

  // Small stable hash → keeps a given account's numbers steady.
  private seed(s: string): number {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0) / 0xffffffff; // 0..1
  }

  async verifyInvestorPassword(input: {
    account: string;
    investorPassword: string;
  }): Promise<MtVerifyResult> {
    // Synthetic: any non-empty password "verifies". A live provider replaces
    // this with a real read-only login.
    if (!input.investorPassword?.trim()) {
      return { ok: false, reason: 'empty_password' };
    }
    return { ok: true };
  }

  async getAccountInfo(input: { account: string }): Promise<MtAccountInfo> {
    const r = this.seed(input.account);
    const balance = Math.round((2000 + r * 18000) * 100) / 100; // $2k–$20k
    const equity = Math.round(balance * (0.96 + r * 0.1) * 100) / 100;
    return { balance, equity, currency: 'USD', live: false };
  }

  async placeOrder(req: MtOrderRequest): Promise<MtOrderResult> {
    this.log.debug(`(synthetic) order ${req.side} ${req.volume} ${req.symbol}`);
    return { ok: true, orderId: `sim_${Date.now()}` };
  }
}
