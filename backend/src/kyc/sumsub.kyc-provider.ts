import { Logger } from '@nestjs/common';
import { createHmac } from 'crypto';
import { KycStatus } from '@prisma/client';
import { KycProvider, KycStartResult, KycWebhookResult } from './kyc.types';

/**
 * Sumsub KYC provider — activated when SUMSUB_APP_TOKEN + SUMSUB_SECRET_KEY are
 * set. Implements the two calls the app needs (create applicant, mint SDK access
 * token) with Sumsub's HMAC request signing, plus webhook signature check +
 * status mapping. Same KycProvider interface, so nothing else changes.
 *
 * Docs: https://docs.sumsub.com/reference (App Token auth, access tokens,
 * applicantReviewed webhook).
 */
export class SumsubKycProvider implements KycProvider {
  readonly name = 'sumsub';
  private readonly log = new Logger('Kyc:sumsub');
  private readonly base = 'https://api.sumsub.com';

  constructor(
    private readonly appToken: string,
    private readonly secretKey: string,
    private readonly levelName: string,
  ) {}

  private sign(ts: number, method: string, path: string, body: string) {
    return createHmac('sha256', this.secretKey)
      .update(`${ts}${method.toUpperCase()}${path}${body}`)
      .digest('hex');
  }

  private async call<T>(method: string, path: string, body?: unknown): Promise<T> {
    const ts = Math.floor(Date.now() / 1000);
    const payload = body ? JSON.stringify(body) : '';
    const res = await fetch(`${this.base}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-App-Token': this.appToken,
        'X-App-Access-Ts': String(ts),
        'X-App-Access-Sig': this.sign(ts, method, path, payload),
      },
      body: payload || undefined,
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`sumsub ${path} -> ${res.status}`);
    return (await res.json()) as T;
  }

  async start(input: { userId: string; email?: string | null }): Promise<KycStartResult> {
    // Ensure an applicant exists (Sumsub dedups by externalUserId).
    let applicantId = '';
    try {
      const applicant = await this.call<{ id: string }>(
        'POST',
        `/resources/applicants?levelName=${encodeURIComponent(this.levelName)}`,
        { externalUserId: input.userId, email: input.email ?? undefined },
      );
      applicantId = applicant.id;
    } catch (e) {
      // Already exists (409) or transient — fetch by externalUserId.
      const found = await this.call<{ id: string }>(
        'GET',
        `/resources/applicants/-;externalUserId=${encodeURIComponent(input.userId)}/one`,
      ).catch(() => null as any);
      applicantId = found?.id ?? '';
      if (!applicantId) throw e;
    }
    const token = await this.call<{ token: string }>(
      'POST',
      `/resources/accessTokens?userId=${encodeURIComponent(input.userId)}&levelName=${encodeURIComponent(this.levelName)}`,
    );
    return { provider: this.name, applicantId, accessToken: token.token };
  }

  parseWebhook(headers: Record<string, string>, rawBody: string): KycWebhookResult | null {
    // Verify the payload digest Sumsub sends in x-payload-digest.
    const digest = headers['x-payload-digest'];
    if (digest) {
      const expected = createHmac('sha256', this.secretKey).update(rawBody).digest('hex');
      if (digest !== expected) {
        this.log.warn('webhook signature mismatch — ignoring');
        return null;
      }
    }
    let body: any;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return null;
    }
    if (body.type !== 'applicantReviewed') return null;
    const answer = body.reviewResult?.reviewAnswer; // GREEN | RED
    const status = answer === 'GREEN' ? KycStatus.verified : KycStatus.rejected;
    return {
      applicantId: body.applicantId,
      status,
      reason: body.reviewResult?.moderationComment ?? body.reviewResult?.clientComment,
    };
  }
}
