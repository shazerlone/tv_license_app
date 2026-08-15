import { Injectable, Logger } from '@nestjs/common';
import { CreatePaymentResult, DepositProvider, WebhookResult } from './deposit-provider';
import { NowPaymentsProvider } from './nowpayments.provider';

/**
 * Resolves the configured crypto deposit processor (CRYPTO_DEPOSIT_PROVIDER) and
 * exposes a provider-agnostic API to the deposits service. Add new processors by
 * implementing DepositProvider and wiring them here — nothing else changes.
 */
@Injectable()
export class CryptoDepositService {
  private readonly logger = new Logger('CryptoDepositService');
  private readonly provider?: DepositProvider;

  constructor() {
    const name = (process.env.CRYPTO_DEPOSIT_PROVIDER ?? '').trim().toLowerCase();
    if (name === 'nowpayments') {
      const key = process.env.NOWPAYMENTS_API_KEY?.trim();
      const secret = process.env.NOWPAYMENTS_IPN_SECRET?.trim();
      if (key && secret) this.provider = new NowPaymentsProvider(key, secret);
      else this.logger.warn('CRYPTO_DEPOSIT_PROVIDER=nowpayments but NOWPAYMENTS_API_KEY / NOWPAYMENTS_IPN_SECRET is missing — crypto deposits stay disabled');
    } else if (name) {
      this.logger.warn(`Unknown CRYPTO_DEPOSIT_PROVIDER "${name}" — crypto deposits stay disabled`);
    }
  }

  get enabled(): boolean {
    return !!this.provider;
  }

  get name(): string {
    return this.provider?.name ?? 'none';
  }

  private ipnUrl(): string | undefined {
    const base = (process.env.PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, '');
    return base ? `${base}/v1/webhooks/deposits/crypto` : undefined;
  }

  createPayment(depositId: string, amountUsd: number, asset: string): Promise<CreatePaymentResult> {
    if (!this.provider) throw new Error('no crypto provider configured');
    return this.provider.createPayment({ depositId, amountUsd, asset, ipnCallbackUrl: this.ipnUrl() });
  }

  verifyWebhook(rawBody: string, headers: Record<string, string | undefined>): WebhookResult {
    if (!this.provider) return { ok: false, status: 'ignored' };
    return this.provider.verifyWebhook(rawBody, headers);
  }
}
