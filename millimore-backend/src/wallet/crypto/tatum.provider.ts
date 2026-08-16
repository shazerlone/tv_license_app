import { Logger } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { ChainDeposit, DepositAddressProvider, DepositNetwork, DEPOSIT_NETWORKS, IncomingTransfer, NewAddress } from './address-provider';

const API_BASE = 'https://api.tatum.io';

// v3 address-derivation path uses the short chain name.
const CHAIN_PATH: Record<DepositNetwork, string> = { tron: 'tron', ethereum: 'ethereum', bsc: 'bsc' };
// v4 subscriptions require NETWORK-QUALIFIED chain names (tron-testnet, etc.).
const SUB_CHAIN: Record<'testnet' | 'mainnet', Record<DepositNetwork, string>> = {
  testnet: { tron: 'tron-testnet', bsc: 'bsc-testnet', ethereum: 'ethereum-sepolia' },
  mainnet: { tron: 'tron-mainnet', bsc: 'bsc-mainnet', ethereum: 'ethereum-mainnet' },
};

/** Map a (possibly network-qualified) Tatum chain back to our base network. */
export function baseNetwork(chain: string): DepositNetwork | undefined {
  const c = (chain ?? '').toLowerCase();
  if (c.includes('tron')) return 'tron';
  if (c.includes('bsc')) return 'bsc';
  if (c.includes('ethereum') || c === 'eth') return 'ethereum';
  return undefined;
}

/**
 * Tatum address-based deposit provider (docs.tatum.io). Derives a per-user USDT
 * address from the master xpub (public key only — private keys never touch the
 * server), subscribes to incoming-tx webhooks for it, and verifies the signed
 * notification. Auto-sweep to the master + gas handling is a later phase (needs
 * KMS / signing) — this covers issue-address → detect-deposit → credit.
 *
 * NOTE: this environment can't reach Tatum, so this is built to spec and
 * unit-tested with stubs; the first real testnet deposit on the server is the
 * live verification (webhook field names may need one small adjustment).
 */
export class TatumProvider implements DepositAddressProvider {
  readonly name = 'tatum';
  readonly networks: DepositNetwork[] = [...DEPOSIT_NETWORKS];
  private readonly logger = new Logger('TatumProvider');

  constructor(
    private readonly apiKey: string,
    private readonly hmacSecret: string,
    private readonly webhookUrl: string | undefined,
  ) {}

  private xpubFor(network: DepositNetwork): string | undefined {
    if (network === 'tron') return process.env.TATUM_XPUB_TRON?.trim();
    if (network === 'ethereum') return process.env.TATUM_XPUB_ETH?.trim();
    if (network === 'bsc') return (process.env.TATUM_XPUB_BSC ?? process.env.TATUM_XPUB_ETH)?.trim(); // same EVM xpub works
    return undefined;
  }

  private subChain(network: DepositNetwork): string {
    const override = process.env[`TATUM_SUB_CHAIN_${network.toUpperCase()}`]?.trim();
    if (override) return override;
    const env = (process.env.TATUM_NETWORK ?? 'testnet').toLowerCase() === 'mainnet' ? 'mainnet' : 'testnet';
    return SUB_CHAIN[env][network];
  }

  async createAddress(userId: string, network: DepositNetwork, index: number): Promise<NewAddress> {
    const xpub = this.xpubFor(network);
    if (!xpub) throw new Error(`no xpub configured for ${network} (set TATUM_XPUB_*)`);
    const res = await fetch(`${API_BASE}/v3/${CHAIN_PATH[network]}/address/${xpub}/${index}`, {
      headers: { 'x-api-key': this.apiKey },
    });
    const json = (await res.json().catch(() => ({}))) as { address?: string; message?: string };
    if (!res.ok || !json.address) throw new Error(`tatum address gen failed: ${res.status} ${json.message ?? ''}`.trim());
    // Register a webhook subscription so incoming deposits notify us. Best-effort:
    // a subscription failure shouldn't block handing the user their address.
    await this.subscribe(json.address, network).catch((e) => this.logger.warn(`subscribe failed for ${json.address}: ${String(e)}`));
    return { address: json.address, derivationIndex: index };
  }

  private async subscribe(address: string, network: DepositNetwork): Promise<void> {
    if (!this.webhookUrl) {
      this.logger.warn('PUBLIC_BASE_URL not set — cannot register deposit webhook subscription');
      return;
    }
    await fetch(`${API_BASE}/v4/subscription`, {
      method: 'POST',
      headers: { 'x-api-key': this.apiKey, 'content-type': 'application/json' },
      body: JSON.stringify({
        type: 'ADDRESS_EVENT',
        attr: { address, chain: this.subChain(network), url: this.webhookUrl },
      }),
    });
  }

  /**
   * Reconciliation: read incoming USDT transfers already on-chain for an address.
   * TRON uses the TRC-20 account endpoint; EVM chains are added later. Returns the
   * raw provider response too, so field-shape surprises are visible.
   */
  async fetchDeposits(address: string, network: DepositNetwork): Promise<{ transfers: IncomingTransfer[]; raw?: unknown }> {
    if (network !== 'tron') {
      return { transfers: [], raw: { note: `rescan not yet implemented for ${network}` } };
    }
    const r = await fetch(`${API_BASE}/v3/tron/transaction/account/${address}/trc20?onlyTo=true`, {
      headers: { 'x-api-key': this.apiKey },
    });
    const raw = (await r.json().catch(() => null)) as unknown;
    const list: any[] = Array.isArray(raw)
      ? raw
      : ((raw as any)?.transactions ?? (raw as any)?.data ?? []);
    const transfers: IncomingTransfer[] = [];
    for (const t of list) {
      const to = t.to ?? t.toAddress ?? t.to_address;
      if (to && to !== address) continue; // incoming only
      const info = t.tokenInfo ?? t.token_info ?? {};
      const symbol = String(info.symbol ?? t.symbol ?? '').toUpperCase();
      if (symbol && symbol !== 'USDT') continue;
      const decimals = Number(info.decimals ?? t.decimals ?? 6);
      const value = Number(t.value ?? t.amount ?? 0);
      const amount = value / Math.pow(10, decimals);
      const txRef = t.txID ?? t.txId ?? t.transaction_id ?? t.hash;
      if (txRef && amount > 0) transfers.push({ txRef: String(txRef), amount });
    }
    return { transfers, raw };
  }

  parseWebhook(rawBody: string, headers: Record<string, string | undefined>): ChainDeposit {
    if (!this.hmacSecret) return { ok: false }; // fail closed
    const provided = (headers['x-payload-hash'] ?? '').trim();
    if (!provided) return { ok: false };

    let b: Record<string, unknown>;
    try {
      b = JSON.parse(rawBody);
    } catch {
      return { ok: false };
    }
    // Tatum: x-payload-hash = base64(HMAC-SHA512(payload, secret)) over the compact
    // JSON. Accept either the raw bytes we received or the canonical re-stringify,
    // so whitespace/transport differences don't cause false rejects.
    const candidates = [rawBody, JSON.stringify(b)];
    const ok = candidates.some((c) => {
      const exp = createHmac('sha512', this.hmacSecret).update(c).digest('base64');
      return provided.length === exp.length && timingSafeEqual(Buffer.from(provided), Buffer.from(exp));
    });
    if (!ok) return { ok: false };
    // ADDRESS_EVENT payload (chain may be network-qualified, e.g. tron-testnet).
    const network = baseNetwork(String(b.chain ?? ''));
    const asset = String(b.asset ?? b.currency ?? '').toUpperCase();
    const type = String(b.type ?? b.txType ?? '').toLowerCase();
    const amount = Math.abs(Number(b.amount ?? 0));
    const address = typeof b.address === 'string' ? b.address : undefined;
    const txRef = (b.txId as string) || (b.hash as string) || undefined;
    // Only credit incoming USDT of positive value (else return verified-but-empty,
    // which creditFromChainDeposit safely ignores).
    if (type && type !== 'incoming' && type !== 'native' && type !== 'token') return { ok: true };
    if (asset && asset !== 'USDT') return { ok: true };
    return { ok: true, network, address, amount, txRef };
  }
}
