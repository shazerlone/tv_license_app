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
   *
   * TRON is queried against TronGrid directly (the authoritative chain indexer),
   * NOT Tatum's history endpoint — Tatum's hosted TRC-20 history index is blind on
   * testnet (returns an empty list even when the transfer exists on-chain). On
   * testnet we probe both Nile and Shasta so we don't have to guess which faucet
   * was used; on mainnet we hit api.trongrid.io. Override the base with
   * TRON_RPC_BASE, and pass TRONGRID_API_KEY to lift rate limits. EVM chains are
   * added later. The raw responses are returned too, so field surprises are visible.
   */
  async fetchDeposits(address: string, network: DepositNetwork): Promise<{ transfers: IncomingTransfer[]; raw?: unknown }> {
    if (network !== 'tron') {
      return { transfers: [], raw: { note: `rescan not yet implemented for ${network}` } };
    }
    const testnet = (process.env.TATUM_NETWORK ?? 'testnet').toLowerCase() !== 'mainnet';
    const override = process.env.TRON_RPC_BASE?.trim();
    const bases = override
      ? [override.replace(/\/+$/, '')]
      : testnet
        ? ['https://nile.trongrid.io', 'https://api.shasta.trongrid.io']
        : ['https://api.trongrid.io'];
    const apiKey = process.env.TRONGRID_API_KEY?.trim();
    const headers: Record<string, string> = apiKey ? { 'TRON-PRO-API-KEY': apiKey } : {};

    const raws: Record<string, unknown> = {};
    const transfers: IncomingTransfer[] = [];
    const seen = new Set<string>();
    for (const base of bases) {
      try {
        const r = await fetch(`${base}/v1/accounts/${address}/transactions/trc20?only_to=true&only_confirmed=true&limit=50`, { headers });
        const raw = (await r.json().catch(() => null)) as unknown;
        raws[base] = raw;
        const list: any[] = Array.isArray((raw as any)?.data) ? (raw as any).data : [];
        for (const t of list) {
          const to = t.to ?? t.to_address ?? t.toAddress;
          if (to && to !== address) continue; // incoming only
          const info = t.token_info ?? t.tokenInfo ?? {};
          const symbol = String(info.symbol ?? t.symbol ?? '').toUpperCase();
          if (symbol && symbol !== 'USDT') continue; // lenient: allow if symbol absent
          const decimals = Number(info.decimals ?? t.decimals ?? 6);
          const value = Number(t.value ?? t.amount ?? 0);
          const amount = value / Math.pow(10, decimals);
          const txRef = t.transaction_id ?? t.txID ?? t.txId ?? t.hash;
          if (txRef && amount > 0 && !seen.has(String(txRef))) {
            seen.add(String(txRef));
            transfers.push({ txRef: String(txRef), amount });
          }
        }
      } catch (e) {
        raws[base] = { error: (e as Error).message };
      }
    }
    return { transfers, raw: raws };
  }

  /**
   * Parse + signature-check a Tatum v4 ADDRESS_EVENT webhook. Field shapes are
   * taken from a REAL delivered payload:
   *   { to, value:"0.05", currency:"ETH", txId, chain:"ethereum-sepolia",
   *     tokenMetadata:{ type, symbol, decimals } }
   * `value` is already human-decimal (NOT base units). The recipient is `to`.
   *
   * We only VERIFY the signature here (sigOk); the crediting-trust decision is the
   * caller's, so an unsigned/mis-signed webhook can fall back to an authoritative
   * on-chain re-check instead of crediting a possibly-forged payload. `ok` means
   * "valid JSON we understood", not "trusted".
   */
  parseWebhook(rawBody: string, headers: Record<string, string | undefined>): ChainDeposit {
    let b: Record<string, any>;
    try {
      b = JSON.parse(rawBody);
    } catch {
      return { ok: false };
    }

    // Signature: x-payload-hash = base64(HMAC-SHA512(payload, secret)). Tatum signs
    // only when an HMAC secret is configured in the dashboard; if none arrives we
    // report sigOk:false and let the caller re-verify on-chain.
    let sigOk = false;
    const provided = (headers['x-payload-hash'] ?? '').trim();
    if (this.hmacSecret && provided) {
      const candidates = [rawBody, JSON.stringify(b)];
      sigOk = candidates.some((c) => {
        const exp = createHmac('sha512', this.hmacSecret).update(c).digest('base64');
        return provided.length === exp.length && timingSafeEqual(Buffer.from(provided), Buffer.from(exp));
      });
    }

    const network = baseNetwork(String(b.chain ?? ''));
    const meta = (b.tokenMetadata ?? {}) as Record<string, any>;
    const asset = String(b.currency ?? meta.symbol ?? b.asset ?? '').toUpperCase();
    // v4 `value` is already whole-unit decimal (e.g. "0.05", "1000").
    const amount = Math.abs(Number(b.value ?? b.amount ?? 0));
    const address = typeof b.to === 'string' ? b.to : typeof b.address === 'string' ? b.address : undefined;
    const txRef = (b.txId as string) || (b.hash as string) || (b.txHash as string) || undefined;
    return { ok: true, sigOk, network, address, amount, asset, txRef };
  }
}
