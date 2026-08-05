import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { genId } from '../common/ids';

export interface YtChatMessage {
  author: string;
  text: string;
}
export interface YtPollResult {
  messages: YtChatMessage[];
  nextPageToken?: string;
  pollingIntervalMillis: number;
}

/**
 * YouTube integration (contract §4.10). Gated by GOOGLE_OAUTH_CLIENT_ID +
 * GOOGLE_OAUTH_CLIENT_SECRET + GOOGLE_OAUTH_REDIRECT_URI. Connects a creator's
 * YouTube account (OAuth2, offline) and reads their live chat via the Data API
 * v3 so it can be piped into the in-app chat. Refresh tokens are AES-256-GCM
 * encrypted. Without env, `enabled` is false and connect endpoints report so.
 *
 * Docs: https://developers.google.com/youtube/v3/live/docs/liveChatMessages/list
 */
@Injectable()
export class YoutubeService {
  private readonly log = new Logger('YoutubeService');
  private readonly clientId?: string;
  private readonly clientSecret?: string;
  private readonly redirectUri?: string;
  private readonly accessCache = new Map<string, { token: string; exp: number }>();

  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
  ) {
    this.clientId = config.get<string>('GOOGLE_OAUTH_CLIENT_ID') || undefined;
    this.clientSecret = config.get<string>('GOOGLE_OAUTH_CLIENT_SECRET') || undefined;
    this.redirectUri = config.get<string>('GOOGLE_OAUTH_REDIRECT_URI') || undefined;
  }

  get enabled(): boolean {
    return !!(this.clientId && this.clientSecret && this.redirectUri);
  }

  private assertEnabled() {
    if (!this.enabled) {
      throw new BadRequestException({ code: 'youtube_not_configured', message: 'YouTube integration is not configured.' });
    }
  }

  /** Consent URL the creator visits to authorize read access to their live chat. */
  getAuthUrl(userId: string): string {
    this.assertEnabled();
    const params = new URLSearchParams({
      client_id: this.clientId!,
      redirect_uri: this.redirectUri!,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent',
      include_granted_scopes: 'true',
      scope: 'https://www.googleapis.com/auth/youtube.readonly',
      state: userId,
    });
    return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  }

  /** OAuth callback: exchange the code, store the refresh token, fetch channel. */
  async handleCallback(code: string, userId: string): Promise<{ connected: boolean; channelTitle?: string }> {
    this.assertEnabled();
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: this.clientId!,
        client_secret: this.clientSecret!,
        redirect_uri: this.redirectUri!,
        grant_type: 'authorization_code',
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!tokenRes.ok) throw new BadRequestException({ code: 'oauth_failed', message: 'YouTube authorization failed.' });
    const tokens = (await tokenRes.json()) as { refresh_token?: string; access_token: string };
    if (!tokens.refresh_token) {
      throw new BadRequestException({ code: 'no_refresh_token', message: 'Re-consent required (no refresh token returned).' });
    }
    const channel = await this.fetchChannel(tokens.access_token).catch(() => undefined);
    await this.prisma.youtubeAccount.upsert({
      where: { userId },
      update: { refreshTokenEnc: this.crypto.encrypt(tokens.refresh_token), channelId: channel?.id, channelTitle: channel?.title },
      create: {
        id: genId('yt'),
        userId,
        refreshTokenEnc: this.crypto.encrypt(tokens.refresh_token),
        channelId: channel?.id,
        channelTitle: channel?.title,
      },
    });
    return { connected: true, channelTitle: channel?.title };
  }

  async status(userId: string) {
    const acct = await this.prisma.youtubeAccount.findUnique({ where: { userId } });
    return { connected: !!acct, channelTitle: acct?.channelTitle ?? null, enabled: this.enabled };
  }

  async disconnect(userId: string) {
    await this.prisma.youtubeAccount.deleteMany({ where: { userId } });
    this.accessCache.delete(userId);
    return { ok: true };
  }

  /** A fresh access token from the stored refresh token (cached ~50 min). */
  async accessToken(userId: string): Promise<string | null> {
    const cached = this.accessCache.get(userId);
    if (cached && cached.exp > Date.now() + 60_000) return cached.token;
    const acct = await this.prisma.youtubeAccount.findUnique({ where: { userId } });
    if (!acct) return null;
    const refresh = this.crypto.decrypt(acct.refreshTokenEnc);
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: this.clientId!,
        client_secret: this.clientSecret!,
        refresh_token: refresh,
        grant_type: 'refresh_token',
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      this.log.warn(`refresh token failed for ${userId}: ${res.status}`);
      return null;
    }
    const j = (await res.json()) as { access_token: string; expires_in: number };
    this.accessCache.set(userId, { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 });
    return j.access_token;
  }

  private async fetchChannel(accessToken: string): Promise<{ id: string; title: string } | undefined> {
    const res = await fetch('https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true', {
      headers: { authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) return undefined;
    const j = (await res.json()) as { items?: { id: string; snippet?: { title?: string } }[] };
    const c = j.items?.[0];
    return c ? { id: c.id, title: c.snippet?.title ?? 'YouTube' } : undefined;
  }

  /** Find the creator's currently-active live chat id (if they're live on YT). */
  async resolveLiveChatId(userId: string): Promise<string | null> {
    const token = await this.accessToken(userId);
    if (!token) return null;
    const res = await fetch(
      'https://www.googleapis.com/youtube/v3/liveBroadcasts?part=snippet&broadcastStatus=active&broadcastType=all',
      { headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(10_000) },
    );
    if (!res.ok) return null;
    const j = (await res.json()) as { items?: { snippet?: { liveChatId?: string } }[] };
    return j.items?.[0]?.snippet?.liveChatId ?? null;
  }

  /** Poll one page of live chat messages. */
  async pollChat(userId: string, liveChatId: string, pageToken?: string): Promise<YtPollResult | null> {
    const token = await this.accessToken(userId);
    if (!token) return null;
    const params = new URLSearchParams({ liveChatId, part: 'snippet,authorDetails', maxResults: '200' });
    if (pageToken) params.set('pageToken', pageToken);
    const res = await fetch(`https://www.googleapis.com/youtube/v3/liveChat/messages?${params.toString()}`, {
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) return null;
    const j = (await res.json()) as {
      nextPageToken?: string;
      pollingIntervalMillis?: number;
      items?: { snippet?: { displayMessage?: string }; authorDetails?: { displayName?: string } }[];
    };
    const messages: YtChatMessage[] = (j.items ?? [])
      .filter((it) => it.snippet?.displayMessage)
      .map((it) => ({ author: it.authorDetails?.displayName ?? 'YouTube', text: it.snippet!.displayMessage! }));
    return { messages, nextPageToken: j.nextPageToken, pollingIntervalMillis: j.pollingIntervalMillis ?? 5000 };
  }
}
