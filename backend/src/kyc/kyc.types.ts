import { KycStatus } from '@prisma/client';

/**
 * KYC provider seam (contract §12). Identity verification is isolated behind
 * this interface so Sumsub (or Onfido, Persona, …) plugs in without touching the
 * app or API contract. A manual provider is the fallback until creds are set.
 */
export const KYC_PROVIDER = Symbol('KYC_PROVIDER');

export interface KycStartResult {
  provider: string;
  applicantId: string;
  /** Short-lived token the mobile SDK uses to launch the flow. */
  accessToken: string;
  /** For manual/dev: no SDK, the app shows a "pending review" state. */
  manual?: boolean;
}

export interface KycWebhookResult {
  applicantId: string;
  status: KycStatus;
  reason?: string;
}

export interface KycProvider {
  readonly name: string;
  /** Create/ensure the provider applicant and mint an SDK access token. */
  start(input: { userId: string; email?: string | null; name?: string }): Promise<KycStartResult>;
  /** Verify + parse a provider webhook into a normalized status update. */
  parseWebhook(headers: Record<string, string>, rawBody: string): KycWebhookResult | null;
}
