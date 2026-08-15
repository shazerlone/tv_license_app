/** A crypto payment processor behind a swappable seam (contract §deposits). */
export interface CreatePaymentInput {
  depositId: string;
  amountUsd: number;
  asset: string; // "USDT" | "BTC" | "ETH" | …
  ipnCallbackUrl?: string;
}

export interface CreatePaymentResult {
  address: string; // the pay-to address shown to the user
  payAmount?: number; // exact crypto amount to send
  payCurrency?: string; // processor pay currency, e.g. "usdttrc20"
  providerRef?: string; // processor payment id
}

/** Outcome of verifying + parsing an inbound processor webhook (IPN). */
export interface WebhookResult {
  ok: boolean; // signature verified
  depositId?: string; // our order id
  status: 'confirmed' | 'failed' | 'pending' | 'ignored';
  txRef?: string; // on-chain hash / provider payment id
}

export interface DepositProvider {
  readonly name: string;
  /** Create a payment and return the address to show the user. */
  createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult>;
  /** Verify signature over the raw body and map the processor status. */
  verifyWebhook(rawBody: string, headers: Record<string, string | undefined>): WebhookResult;
}
