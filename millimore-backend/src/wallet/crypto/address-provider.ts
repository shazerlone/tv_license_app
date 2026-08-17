/** Networks we issue USDT deposit addresses on. */
export const DEPOSIT_NETWORKS = ['tron', 'ethereum', 'bsc'] as const;
export type DepositNetwork = (typeof DEPOSIT_NETWORKS)[number];

export interface NewAddress {
  address: string;
  providerRef?: string;
  derivationIndex?: number;
}

/** A normalized on-chain deposit event, extracted from a processor webhook. */
export interface ChainDeposit {
  ok: boolean; // payload parsed (valid JSON we understand)
  sigOk?: boolean; // HMAC signature verified (undefined = provider doesn't sign)
  network?: DepositNetwork;
  address?: string; // the deposit address that received funds
  amount?: number; // amount received (in whole units, e.g. USDT)
  asset?: string; // token symbol, e.g. "USDT" / "ETH"
  txRef?: string; // on-chain tx hash (dedupe key)
  confirmed?: boolean; // false = detected but still unconfirmed (mempool); undefined = treat as confirmed
}

/**
 * Address-based deposit processor (Tatum Gas Pump, etc.): issues a persistent
 * per-user address per network and notifies us via webhook when funds arrive,
 * auto-forwarding them to the master wallet. Swappable behind CryptoAddressService.
 */
export interface IncomingTransfer {
  txRef: string;
  amount: number; // USDT amount
}

/** Result of a consolidation sweep of a deposit address to the master wallet. */
export interface SweepResult {
  status: 'broadcast' | 'skipped' | 'failed';
  txRef?: string; // on-chain tx hash / Tatum signatureId reference
  reason?: string; // why skipped/failed
  raw?: unknown; // provider response, for testnet iteration
}

export interface DepositAddressProvider {
  readonly name: string;
  readonly networks: DepositNetwork[];
  /** `index` is a unique HD derivation index per network (managed by the caller). */
  createAddress(userId: string, network: DepositNetwork, index: number): Promise<NewAddress>;
  /** Verify + normalize an inbound deposit webhook. May be async (network I/O). */
  parseWebhook(
    rawBody: string,
    headers: Record<string, string | undefined>,
  ): ChainDeposit | Promise<ChainDeposit>;
  /** Reconciliation: fetch incoming USDT transfers already on-chain for an address. */
  fetchDeposits?(address: string, network: DepositNetwork): Promise<{ transfers: IncomingTransfer[]; raw?: unknown }>;
  /** Current on-chain USDT balance sitting on an address (whole units). */
  usdtBalance?(address: string, network: DepositNetwork): Promise<{ balance: number; raw?: unknown }>;
  /** True when this provider can consolidate (sweep) deposit addresses to a master. */
  readonly canSweep?: boolean;
  /**
   * Consolidate the USDT on a deposit address to the master wallet. Non-custodial:
   * the provider delegates signing to a KMS (signatureId) — no private key here.
   * `index` is the address's HD/gas-pump derivation index.
   */
  sweep?(address: string, network: DepositNetwork, index: number): Promise<SweepResult>;
}
