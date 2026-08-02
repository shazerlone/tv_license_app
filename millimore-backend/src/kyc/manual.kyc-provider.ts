import { KycProvider, KycStartResult, KycWebhookResult } from './kyc.types';

/**
 * Fallback KYC provider used until a real one (Sumsub) is configured. It creates
 * a local "applicant", returns a manual flag so the app shows a "submitted —
 * pending review" state, and an admin verifies/rejects in the dashboard.
 */
export class ManualKycProvider implements KycProvider {
  readonly name = 'manual';

  async start(input: { userId: string }): Promise<KycStartResult> {
    return {
      provider: this.name,
      applicantId: `manual_${input.userId}`,
      accessToken: 'manual',
      manual: true,
    };
  }

  parseWebhook(): KycWebhookResult | null {
    // No external webhooks in manual mode; admin drives status changes.
    return null;
  }
}
