import { Logger } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { CreatePaymentInput, CreatePaymentResult, DepositProvider, WebhookResult } from './deposit-provider';

const API_BASE = 'https://api.nowpayments.io/v1';

// Our asset → NOWPayments pay_currency. USDT/USDC default to the cheap TRON
// network; override via NOWPAYMENTS_ASSET_MAP (JSON) if you prefer ERC-20 etc.
const DEFAULT_MAP: Record<string, string> = {
  USDT: 'usdttrc20',
  USDC: 'usdctrc20',
  BTC: 'btc',
  ETH: 'eth',
  SOL: 'sol',
};

/**
 * NOWPayments crypto processor (https://nowpayments.io). Creates a payment per
 * deposit and confirms via signed IPN. Signature: HMAC-SHA512 over the JSON body
 * with keys sorted recursively, using the IPN secret, in the `x-nowpayments-sig`
 * header (their documented scheme).
 */
export class NowPaymentsProvider implements DepositProvider {
  readonly name = 'nowpayments';
  private readonly logger = new Logger('NowPaymentsProvider');
  private readonly map: Record<string, string>;

  constructor(
    private readonly apiKey: string,
    private readonly ipnSecret: string,
  ) {
    let map = DEFAULT_MAP;
    const raw = process.env.NOWPAYMENTS_ASSET_MAP;
    if (raw) {
      try {
        map = { ...DEFAULT_MAP, ...JSON.parse(raw) };
      } catch {
        /* keep defaults */
      }
    }
    this.map = map;
  }

  private payCurrency(asset: string): string {
    return this.map[asset.toUpperCase()] ?? asset.toLowerCase();
  }

  async createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult> {
    const res = await fetch(`${API_BASE}/payment`, {
      method: 'POST',
      headers: { 'x-api-key': this.apiKey, 'content-type': 'application/json' },
      body: JSON.stringify({
        price_amount: input.amountUsd,
        price_currency: 'usd',
        pay_currency: this.payCurrency(input.asset),
        order_id: input.depositId,
        order_description: `Millimore wallet deposit ${input.depositId}`,
        ...(input.ipnCallbackUrl ? { ipn_callback_url: input.ipnCallbackUrl } : {}),
      }),
    });
    const json = (await res.json().catch(() => ({}))) as {
      pay_address?: string;
      pay_amount?: number;
      pay_currency?: string;
      payment_id?: string | number;
      message?: string;
    };
    if (!res.ok || !json.pay_address) {
      throw new Error(`NOWPayments payment failed: ${res.status} ${json.message ?? ''}`.trim());
    }
    return {
      address: json.pay_address,
      payAmount: json.pay_amount,
      payCurrency: json.pay_currency,
      providerRef: json.payment_id != null ? String(json.payment_id) : undefined,
    };
  }

  verifyWebhook(rawBody: string, headers: Record<string, string | undefined>): WebhookResult {
    const provided = (headers['x-nowpayments-sig'] ?? '').trim();
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(rawBody);
    } catch {
      return { ok: false, status: 'ignored' };
    }
    const expected = createHmac('sha512', this.ipnSecret)
      .update(JSON.stringify(sortDeep(parsed)))
      .digest('hex');
    const ok =
      provided.length === expected.length &&
      timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
    if (!ok) return { ok: false, status: 'ignored' };

    const depositId = typeof parsed.order_id === 'string' ? parsed.order_id : undefined;
    const paymentStatus = String(parsed.payment_status ?? '');
    const txRef =
      (typeof parsed.payin_hash === 'string' && parsed.payin_hash) ||
      (parsed.payment_id != null ? `nowpayments:${String(parsed.payment_id)}` : undefined);
    return { ok: true, depositId, status: mapStatus(paymentStatus), txRef };
  }
}

/** NOWPayments payment_status → our deposit outcome. */
function mapStatus(s: string): WebhookResult['status'] {
  if (s === 'finished') return 'confirmed';
  if (s === 'failed' || s === 'refunded' || s === 'expired') return 'failed';
  // waiting | confirming | confirmed | sending | partially_paid → not terminal yet
  return 'pending';
}

/** Recursively sort object keys (NOWPayments signs the sorted JSON). */
function sortDeep(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortDeep);
  if (value && typeof value === 'object') {
    return Object.keys(value as Record<string, unknown>)
      .sort()
      .reduce<Record<string, unknown>>((acc, k) => {
        acc[k] = sortDeep((value as Record<string, unknown>)[k]);
        return acc;
      }, {});
  }
  return value;
}
