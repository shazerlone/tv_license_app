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
  ok: boolean; // signature verified
  network?: DepositNetwork;
  address?: string; // the deposit address that received funds
  amount?: number; // USDT amount received
  txRef?: string; // on-chain tx hash (dedupe key)
}

/**
 * Address-based deposit processor (Tatum Gas Pump, etc.): issues a persistent
 * per-user address per network and notifies us via webhook when funds arrive,
 * auto-forwarding them to the master wallet. Swappable behind CryptoAddressService.
 */
export interface DepositAddressProvider {
  readonly name: string;
  readonly networks: DepositNetwork[];
  createAddress(userId: string, network: DepositNetwork): Promise<NewAddress>;
  /** Verify + normalize an inbound deposit webhook. */
  parseWebhook(rawBody: string, headers: Record<string, string | undefined>): ChainDeposit;
}
