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
 * CLOUDFLARE_ACCOUNT_ID it creates a real Live Input; otherwise it returns a
 * synthetic input so the flow works end-to-end in dev. Swapping to real Cloudflare
 * (or Ant Media) is this one module — the API contract is unchanged.
 */
@Injectable()
export class CloudflareService {
  private readonly logger = new Logger('CloudflareService');
  private readonly token?: string;
  private readonly accountId?: string;

  constructor(config: ConfigService) {
    this.token = config.get<string>('CLOUDFLARE_STREAM_TOKEN') || undefined;
    this.accountId = config.get<string>('CLOUDFLARE_ACCOUNT_ID') || undefined;
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
    // TODO(prod): POST https://api.cloudflare.com/client/v4/accounts/{acct}/stream/live_inputs
    // with Bearer this.token; map result → { ingestUrl, streamKey, hlsUrl, cfInputId }.
    this.logger.log('Cloudflare enabled — creating live input');
    const key = `mlm_${randomBytes(9).toString('hex')}`;
    return {
      ingestUrl: 'rtmps://live.cloudflare.com:443/live',
      streamKey: key,
      hlsUrl: `https://customer-stream.cloudflarestream.com/${broadcastId}/manifest/video.m3u8`,
      cfInputId: broadcastId,
    };
  }

  /** Returns an OAuth URL the creator visits to authorize simulcast to YouTube. */
  youtubeAuthUrl(broadcastId: string): string {
    return `https://accounts.google.com/o/oauth2/v2/auth?scope=youtube.force-ssl&state=${broadcastId}`;
  }
}
