import { createHash, createHmac, timingSafeEqual } from 'crypto';
import { ChainDeposit, DepositAddressProvider, DepositNetwork, DEPOSIT_NETWORKS, NewAddress } from './address-provider';

/**
 * DEV/TESTNET-ONLY address provider. Generates deterministic, clearly-fake
 * addresses and verifies a simple HMAC-SHA256 webhook so the full deposit →
 * credit loop can be exercised without a real processor. Never enabled in
 * production (guarded by NODE_ENV in CryptoAddressService).
 */
export class MockAddressProvider implements DepositAddressProvider {
  readonly name = 'mock';
  readonly networks: DepositNetwork[] = [...DEPOSIT_NETWORKS];

  constructor(private readonly webhookSecret: string) {}

  async createAddress(userId: string, network: DepositNetwork): Promise<NewAddress> {
    const h = createHash('sha256').update(`${network}:${userId}`).digest('hex');
    const prefix = network === 'tron' ? 'T' : '0x';
    return { address: `MOCK_${prefix}${h.slice(0, 34)}`, providerRef: `mock_${h.slice(0, 12)}` };
  }

  parseWebhook(rawBody: string, headers: Record<string, string | undefined>): ChainDeposit {
    const provided = (headers['x-signature'] ?? '').trim();
    const expected = createHmac('sha256', this.webhookSecret).update(rawBody).digest('hex');
    const ok =
      !!this.webhookSecret &&
      provided.length === expected.length &&
      timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
    if (!ok) return { ok: false };
    let b: { network?: string; address?: string; amount?: number; txRef?: string };
    try {
      b = JSON.parse(rawBody);
    } catch {
      return { ok: false };
    }
    return {
      ok: true,
      network: b.network as DepositNetwork,
      address: b.address,
      amount: typeof b.amount === 'number' ? b.amount : Number(b.amount),
      txRef: b.txRef,
    };
  }
}
