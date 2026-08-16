import { Injectable, Logger } from '@nestjs/common';
import { ChainDeposit, DepositAddressProvider, DepositNetwork } from './address-provider';
import { MockAddressProvider } from './mock-address.provider';
import { TatumProvider } from './tatum.provider';

/**
 * Resolves the address-based crypto deposit provider (CRYPTO_ADDRESS_PROVIDER).
 * Phase 1 ships a dev/testnet `mock` provider; Phase 2 adds `tatum` (Gas Pump).
 * Disabled by default, so production issues no addresses until real keys exist.
 */
@Injectable()
export class CryptoAddressService {
  private readonly logger = new Logger('CryptoAddressService');
  private readonly provider?: DepositAddressProvider;

  constructor() {
    const name = (process.env.CRYPTO_ADDRESS_PROVIDER ?? '').trim().toLowerCase();
    const isProd = process.env.NODE_ENV === 'production';
    if (name === 'mock') {
      if (isProd) {
        this.logger.warn('CRYPTO_ADDRESS_PROVIDER=mock is ignored in production');
      } else {
        this.provider = new MockAddressProvider(process.env.CRYPTO_ADDRESS_WEBHOOK_SECRET ?? 'dev-secret');
        this.logger.log('Deposit addresses: MOCK provider (dev/testnet only)');
      }
    } else if (name === 'tatum') {
      const key = process.env.TATUM_API_KEY?.trim();
      const hmac = process.env.TATUM_HMAC_SECRET?.trim() ?? '';
      const base = (process.env.PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, '');
      const webhookUrl = base ? `${base}/v1/webhooks/deposits/chain` : undefined;
      if (key) {
        this.provider = new TatumProvider(key, hmac, webhookUrl);
        this.logger.log(`Deposit addresses: Tatum provider (${process.env.TATUM_NETWORK ?? 'per-key'} network)`);
        if (!hmac) this.logger.warn('TATUM_HMAC_SECRET not set — deposit webhooks will be rejected until it is');
      } else {
        this.logger.warn('CRYPTO_ADDRESS_PROVIDER=tatum but TATUM_API_KEY is missing — deposit addresses disabled');
      }
    } else if (name) {
      this.logger.warn(`Unknown CRYPTO_ADDRESS_PROVIDER "${name}" — deposit addresses disabled`);
    }
  }

  get enabled(): boolean {
    return !!this.provider;
  }

  get name(): string {
    return this.provider?.name ?? 'none';
  }

  get networks(): DepositNetwork[] {
    return this.provider?.networks ?? [];
  }

  createAddress(userId: string, network: DepositNetwork, index: number) {
    if (!this.provider) throw new Error('no address provider configured');
    return this.provider.createAddress(userId, network, index);
  }

  async parseWebhook(rawBody: string, headers: Record<string, string | undefined>): Promise<ChainDeposit> {
    if (!this.provider) return { ok: false };
    return this.provider.parseWebhook(rawBody, headers);
  }
}
