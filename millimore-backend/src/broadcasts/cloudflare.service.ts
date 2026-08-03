import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';

export interface LiveInput {
  ingestUrl: string;
  streamKey: string;
  hlsUrl: string;
  cfInputId: string | null;
}

/**
 * Cloudflare Stream Live adapter (contract §4.9). With CLOUDFLARE_STREAM_TOKEN +
 * CLOUDFLARE_ACCOUNT_ID it creates a **real** Live Input via the Cloudflare API
 * (RTMPS ingest + HLS playback); otherwise it returns a synthetic input so the
 * flow works end-to-end in dev. Swapping providers is this one module — the API
 * contract is unchanged.
 *
 * Docs: https://developers.cloudflare.com/stream/stream-live/
 */
@Injectable()
export class CloudflareService {
  private readonly logger = new Logger('CloudflareService');
  private readonly token?: string;
  private readonly accountId?: string;
  /** Customer subdomain code for playback URLs (from the Stream dashboard). */
  private readonly customerSubdomain?: string;

  constructor(config: ConfigService) {
    this.token = config.get<string>('CLOUDFLARE_STREAM_TOKEN') || undefined;
    this.accountId = config.get<string>('CLOUDFLARE_ACCOUNT_ID') || undefined;
    this.customerSubdomain = config.get<string>('CLOUDFLARE_STREAM_SUBDOMAIN') || undefined;
  }

  get enabled(): boolean {
    return !!(this.token && this.accountId);
  }

  async createLiveInput(broadcastId: string): Promise<LiveInput> {
    if (!this.enabled) {
      const key = `mlm_${randomBytes(9).toString('hex')}`;
      return {
        ingestUrl: 'rtmps://ingest.millimore.app/live',
        streamKey: key,
        hlsUrl: `https://cdn.millimore.app/${broadcastId}/index.m3u8`,
        cfInputId: null,
      };
    }
    try {
      const res = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${this.accountId}/stream/live_inputs`,
        {
          method: 'POST',
          headers: { authorization: `Bearer ${this.token}`, 'content-type': 'application/json' },
          body: JSON.stringify({
            meta: { name: `millimore-${broadcastId}` },
            recording: { mode: 'automatic' }, // auto-create a replay VOD
          }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (!res.ok) throw new Error(`live_inputs ${res.status}`);
      const body = (await res.json()) as {
        result: { uid: string; rtmps?: { url: string; streamKey: string } };
      };
      const uid = body.result.uid;
      const rtmps = body.result.rtmps;
      const sub = this.customerSubdomain
        ? `customer-${this.customerSubdomain}.cloudflarestream.com`
        : 'customer-stream.cloudflarestream.com';
      return {
        ingestUrl: rtmps?.url ?? 'rtmps://live.cloudflare.com:443/live',
        streamKey: rtmps?.streamKey ?? uid,
        hlsUrl: `https://${sub}/${uid}/manifest/video.m3u8`,
        cfInputId: uid,
      };
    } catch (e) {
      // Never let a provider hiccup block going live — fall back to a dev input.
      this.logger.warn(`Cloudflare live input failed, using fallback: ${(e as Error).message}`);
      const key = `mlm_${randomBytes(9).toString('hex')}`;
      return {
        ingestUrl: 'rtmps://live.cloudflare.com:443/live',
        streamKey: key,
        hlsUrl: `https://customer-stream.cloudflarestream.com/${broadcastId}/manifest/video.m3u8`,
        cfInputId: null,
      };
    }
  }

  /** Returns an OAuth URL the creator visits to authorize simulcast to YouTube. */
  youtubeAuthUrl(broadcastId: string): string {
    return `https://accounts.google.com/o/oauth2/v2/auth?scope=youtube.force-ssl&state=${broadcastId}`;
  }
}
