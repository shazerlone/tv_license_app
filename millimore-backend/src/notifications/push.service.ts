import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

const b64url = (b: Buffer | string) =>
  Buffer.from(b).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/**
 * Push delivery via the **FCM HTTP v1 API** (the legacy server-key API was
 * removed by Google in 2024). Configure with a Firebase service-account JSON in
 * `FCM_SERVICE_ACCOUNT_JSON` (raw JSON) or `FCM_SERVICE_ACCOUNT_B64` (base64).
 * Without it, delivery falls back to logging (dev) — the device registry and all
 * trigger points stay live, so enabling real push is pure config.
 *
 * Auth: sign a JWT with the service-account key → exchange for an OAuth2 access
 * token (cached ~55 min) → POST messages:send. No external SDK.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger('PushService');
  private readonly sa?: ServiceAccount;
  private tokenCache?: { token: string; exp: number };

  constructor(config: ConfigService, private readonly prisma: PrismaService) {
    this.sa = this.loadServiceAccount(config);
    if (this.sa) this.logger.log('FCM HTTP v1 enabled');
  }

  private loadServiceAccount(config: ConfigService): ServiceAccount | undefined {
    const b64 = config.get<string>('FCM_SERVICE_ACCOUNT_B64');
    const raw =
      config.get<string>('FCM_SERVICE_ACCOUNT_JSON') ||
      (b64 ? Buffer.from(b64, 'base64').toString('utf8') : undefined);
    if (!raw) return undefined;
    try {
      const j = JSON.parse(raw);
      if (j.client_email && j.private_key && j.project_id) {
        return { client_email: j.client_email, private_key: j.private_key, project_id: j.project_id };
      }
      this.logger.warn('FCM service account missing client_email/private_key/project_id');
    } catch (e) {
      this.logger.warn(`FCM service account JSON invalid: ${(e as Error).message}`);
    }
    return undefined;
  }

  /** Mint (and cache) a Google OAuth2 access token for FCM. */
  private async accessToken(): Promise<string> {
    if (this.tokenCache && this.tokenCache.exp > Date.now() + 60_000) return this.tokenCache.token;
    const sa = this.sa!;
    const now = Math.floor(Date.now() / 1000);
    const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claim = b64url(
      JSON.stringify({
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    );
    const signature = b64url(createSign('RSA-SHA256').update(`${header}.${claim}`).sign(sa.private_key));
    const assertion = `${header}.${claim}.${signature}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error(`oauth token ${res.status}`);
    const j = (await res.json()) as { access_token: string; expires_in: number };
    this.tokenCache = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 };
    return j.access_token;
  }

  async sendToUser(userId: string, msg: { title: string; body?: string; data?: object }) {
    const devices = await this.prisma.device.findMany({
      where: { userId },
      select: { token: true, platform: true },
    });
    if (devices.length === 0) return;

    if (!this.sa) {
      this.logger.debug(`[push:dev] → ${devices.length} device(s) of ${userId}: ${msg.title}`);
      return;
    }

    let token: string;
    try {
      token = await this.accessToken();
    } catch (e) {
      this.logger.warn(`push auth failed: ${(e as Error).message}`);
      return;
    }

    // FCM data payload values must be strings.
    const data = Object.fromEntries(
      Object.entries(msg.data ?? {}).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)]),
    );
    const url = `https://fcm.googleapis.com/v1/projects/${this.sa.project_id}/messages:send`;

    await Promise.all(
      devices.map(async (d) => {
        try {
          const res = await fetch(url, {
            method: 'POST',
            headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
            body: JSON.stringify({
              message: { token: d.token, notification: { title: msg.title, body: msg.body }, data },
            }),
            signal: AbortSignal.timeout(8000),
          });
          if (res.status === 404 || res.status === 400) {
            // Stale/invalid token — prune it so we stop trying.
            await this.prisma.device.deleteMany({ where: { token: d.token } });
          }
        } catch (e) {
          this.logger.warn(`push send failed: ${(e as Error).message}`);
        }
      }),
    );
  }
}
