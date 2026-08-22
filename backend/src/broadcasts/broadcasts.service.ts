import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { BadRequestException } from '@nestjs/common';
import { Broadcast, BroadcastOutput } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CloudflareService } from './cloudflare.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { YoutubeIngestService } from '../youtube/youtube-ingest.service';
import { RealtimeBus } from '../realtime/realtime.bus';
import { genId } from '../common/ids';
import {
  BroadcastDto,
  CreateBroadcastDto,
  LiveChatMessageDto,
  BroadcastSummaryDto,
} from './dto/broadcast.dto';
import { BroadcastOutputDto, CreateOutputDto } from './dto/output.dto';

/** Default RTMP ingest endpoints for the common simulcast platforms. */
const PLATFORM_URLS: Record<string, string> = {
  youtube: 'rtmp://a.rtmp.youtube.com/live2',
  facebook: 'rtmps://live-api-s.facebook.com:443/rtmp/',
  twitch: 'rtmp://live.twitch.tv/app',
};

@Injectable()
export class BroadcastsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cf: CloudflareService,
    private readonly notifications: NotificationsService,
    private readonly bus: RealtimeBus,
    private readonly crypto: CryptoService,
    private readonly ytIngest: YoutubeIngestService,
  ) {}

  /** Cloudflare Stream low-latency WebRTC (WHEP) playback URL, derived from the
   *  HLS manifest URL (…/<uid>/manifest/video.m3u8 → …/<uid>/webRTC/play). Returns
   *  null for the dev/fallback host that has no WebRTC endpoint. */
  private whepFromHls(hls: string | null | undefined): string | null {
    if (!hls) return null;
    const m = hls.match(/^(https:\/\/[^/]+\/[^/]+)\/manifest\/video\.m3u8/);
    if (!m || hls.includes('cdn.millimore.app')) return null;
    return `${m[1]}/webRTC/play`;
  }

  private toDto(
    b: Broadcast,
    owner = false,
    identity?: { name?: string | null; username?: string | null; photoUrl?: string | null },
  ): BroadcastDto {
    return {
      id: b.id,
      creatorId: b.creatorId,
      traderId: b.traderId ?? null,
      name: identity?.name ?? null,
      username: identity?.username ?? null,
      photoUrl: identity?.photoUrl ?? null,
      title: b.title,
      phase: b.phase,
      // Ingest credentials are only exposed to the broadcasting creator.
      ingestUrl: owner ? b.ingestUrl : undefined,
      streamKey: owner ? b.streamKey : undefined,
      whipUrl: owner ? b.whipUrl : undefined,
      hlsUrl: b.hlsUrl,
      whepUrl: this.whepFromHls(b.hlsUrl),
      viewers: b.viewers,
      peakViewers: b.peakViewers,
      startedAt: b.startedAt ? b.startedAt.toISOString() : null,
      endedAt: b.endedAt ? b.endedAt.toISOString() : null,
      destinations: (b.destinations as unknown[]) ?? [],
    };
  }

  async create(userId: string, dto: CreateBroadcastDto): Promise<BroadcastDto> {
    const id = genId('b');
    const input = await this.cf.createLiveInput(id);
    const trader = await this.prisma.trader.findUnique({ where: { userId }, select: { id: true } });
    const b = await this.prisma.broadcast.create({
      data: {
        id,
        creatorId: userId,
        traderId: trader?.id ?? null,
        title: dto.title,
        phase: 'connecting',
        ingestUrl: input.ingestUrl,
        streamKey: input.streamKey,
        whipUrl: input.whipUrl,
        hlsUrl: input.hlsUrl,
        cfInputId: input.cfInputId,
      },
    });
    return this.toDto(b, true);
  }

  async start(userId: string, id: string): Promise<BroadcastDto> {
    const b = await this.ownedOrThrow(userId, id);
    const updated = await this.prisma.broadcast.update({
      where: { id },
      data: { phase: 'live', startedAt: b.startedAt ?? new Date() },
    });

    // isLive is driven by real broadcast lifecycle only (never seeded).
    if (b.traderId) {
      await this.prisma.trader.update({ where: { id: b.traderId }, data: { isLive: true } });
    }

    // Pipe the creator's YouTube live chat into the in-app chat (no-op unless
    // YouTube is configured + the creator is connected and live on YouTube).
    void this.ytIngest.start(id, userId);

    // Notify followers that a trader they follow went live (contract §6a).
    if (b.traderId) {
      const subs = await this.prisma.subscription.findMany({
        where: { traderId: b.traderId },
        select: { userId: true },
      });
      const creator = await this.prisma.user.findUnique({ where: { id: userId }, select: { name: true } });
      for (const s of subs) {
        await this.notifications.pushEvent(s.userId, 'trader.live.started', `${creator?.name} is live`, {
          data: { traderId: b.traderId, name: creator?.name, broadcastId: id },
        });
      }
    }
    return this.toDto(updated, true);
  }

  async end(userId: string, id: string): Promise<BroadcastSummaryDto> {
    const b = await this.ownedOrThrow(userId, id);
    this.ytIngest.stop(id);
    const endedAt = new Date();
    await this.prisma.broadcast.update({
      where: { id },
      data: { phase: 'ended', endedAt, viewers: 0 },
    });
    // Clear isLive unless the trader still has another live broadcast.
    if (b.traderId) {
      const stillLive = await this.prisma.broadcast.count({
        where: { traderId: b.traderId, phase: 'live', id: { not: id } },
      });
      if (stillLive === 0) {
        await this.prisma.trader.update({ where: { id: b.traderId }, data: { isLive: false } });
      }
    }
    const duration = b.startedAt ? Math.round((endedAt.getTime() - b.startedAt.getTime()) / 1000) : 0;
    // trades/pnl come from on-stream orders (milestone 6 MT bridge).
    return { duration, peakViewers: b.peakViewers, trades: 0, pnl: 0 };
  }

  async get(id: string, userId: string): Promise<BroadcastDto> {
    const b = await this.getOrThrow(id);
    return this.toDto(b, b.creatorId === userId);
  }

  async live(): Promise<BroadcastDto[]> {
    const rows = await this.prisma.broadcast.findMany({
      where: { phase: 'live' },
      orderBy: { startedAt: 'desc' },
    });
    if (rows.length === 0) return [];
    // Attach trader identity so the app can render live cards directly.
    const traderIds = [...new Set(rows.map((r) => r.traderId).filter((x): x is string => !!x))];
    const creatorIds = [...new Set(rows.map((r) => r.creatorId))];
    const [traders, users] = await Promise.all([
      traderIds.length
        ? this.prisma.trader.findMany({ where: { id: { in: traderIds } }, select: { id: true, name: true, username: true, photoUrl: true } })
        : Promise.resolve([]),
      this.prisma.user.findMany({ where: { id: { in: creatorIds } }, select: { id: true, name: true, username: true, photoUrl: true } }),
    ]);
    const traderById = new Map(traders.map((t) => [t.id, t] as const));
    const userById = new Map(users.map((u) => [u.id, u] as const));
    return rows.map((b) => {
      const t = b.traderId ? traderById.get(b.traderId) : undefined;
      const u = userById.get(b.creatorId);
      return this.toDto(b, false, {
        name: t?.name ?? u?.name ?? null,
        username: t?.username ?? u?.username ?? null,
        photoUrl: t?.photoUrl ?? u?.photoUrl ?? null,
      });
    });
  }

  // ── destinations (simulcast) ────────────────────────────────────────
  async connectYoutube(userId: string, id: string): Promise<{ authUrl: string }> {
    await this.ownedOrThrow(userId, id);
    return { authUrl: this.cf.youtubeAuthUrl(id) };
  }

  async disconnectDestination(userId: string, id: string, platform: string): Promise<void> {
    const b = await this.ownedOrThrow(userId, id);
    const dests = ((b.destinations as any[]) ?? []).filter((d) => d.id !== platform);
    await this.prisma.broadcast.update({ where: { id }, data: { destinations: dests } });
  }

  // ── chat & reactions ────────────────────────────────────────────────
  async chat(id: string): Promise<LiveChatMessageDto[]> {
    await this.getOrThrow(id);
    const rows = await this.prisma.broadcastChat.findMany({
      where: { broadcastId: id },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
    return rows.map((c) => ({
      author: c.author,
      text: c.text,
      source: c.source,
      byHost: c.byHost,
      createdAt: c.createdAt.toISOString(),
    }));
  }

  async sendChat(userId: string, id: string, text: string): Promise<LiveChatMessageDto> {
    const b = await this.getOrThrow(id);
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true, username: true },
    });
    const byHost = b.creatorId === userId;
    const row = await this.prisma.broadcastChat.create({
      data: {
        id: genId('lc'),
        broadcastId: id,
        author: user?.username ?? user?.name ?? 'user',
        text,
        source: 'millimore',
        byHost,
      },
    });
    const dto: LiveChatMessageDto = {
      author: row.author,
      text: row.text,
      source: row.source,
      byHost: row.byHost,
      createdAt: row.createdAt.toISOString(),
    };
    this.bus.emitBroadcast(id, { ch: `broadcast:${id}`, type: 'chat', data: dto });
    return dto;
  }

  async react(id: string, count = 1): Promise<void> {
    await this.getOrThrow(id);
    this.bus.emitBroadcast(id, { ch: `broadcast:${id}`, type: 'reaction', data: { count } });
  }

  // ── helpers ─────────────────────────────────────────────────────────
  // ── simulcast outputs (milestone 13) ───────────────────────────────
  private toOutputDto(o: BroadcastOutput): BroadcastOutputDto {
    return {
      id: o.id,
      platform: o.platform,
      targetUrl: o.targetUrl,
      masked: o.masked,
      enabled: o.enabled,
      createdAt: o.createdAt.toISOString(),
    };
  }

  /** Add a simulcast destination (YouTube/Facebook/Twitch/custom RTMP). */
  async addOutput(userId: string, broadcastId: string, dto: CreateOutputDto): Promise<BroadcastOutputDto> {
    const b = await this.ownedOrThrow(userId, broadcastId);
    const url = dto.url ?? PLATFORM_URLS[dto.platform];
    if (!url) {
      throw new BadRequestException({ code: 'url_required', message: 'An RTMP url is required for a custom destination.' });
    }
    const count = await this.prisma.broadcastOutput.count({ where: { broadcastId } });
    if (count >= 50) {
      throw new BadRequestException({ code: 'output_limit', message: 'Maximum of 50 simulcast destinations.' });
    }
    const cfOutputId = await this.cf.addOutput(b.cfInputId, url, dto.streamKey);
    const masked = `${dto.platform} ••••${dto.streamKey.replace(/\s+/g, '').slice(-4)}`;
    const output = await this.prisma.broadcastOutput.create({
      data: {
        id: genId('out'),
        broadcastId,
        platform: dto.platform,
        targetUrl: url,
        streamKeyEnc: this.crypto.encrypt(dto.streamKey),
        masked,
        cfOutputId,
      },
    });
    return this.toOutputDto(output);
  }

  async listOutputs(userId: string, broadcastId: string): Promise<BroadcastOutputDto[]> {
    await this.ownedOrThrow(userId, broadcastId);
    const rows = await this.prisma.broadcastOutput.findMany({
      where: { broadcastId },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map((o) => this.toOutputDto(o));
  }

  async toggleOutput(userId: string, broadcastId: string, outputId: string, enabled: boolean): Promise<BroadcastOutputDto> {
    const b = await this.ownedOrThrow(userId, broadcastId);
    const output = await this.getOutputOrThrow(broadcastId, outputId);
    await this.cf.setOutputEnabled(b.cfInputId, output.cfOutputId, enabled);
    const updated = await this.prisma.broadcastOutput.update({ where: { id: outputId }, data: { enabled } });
    return this.toOutputDto(updated);
  }

  async removeOutput(userId: string, broadcastId: string, outputId: string): Promise<{ ok: boolean }> {
    const b = await this.ownedOrThrow(userId, broadcastId);
    const output = await this.getOutputOrThrow(broadcastId, outputId);
    await this.cf.deleteOutput(b.cfInputId, output.cfOutputId);
    await this.prisma.broadcastOutput.delete({ where: { id: outputId } });
    return { ok: true };
  }

  private async getOutputOrThrow(broadcastId: string, outputId: string): Promise<BroadcastOutput> {
    const o = await this.prisma.broadcastOutput.findFirst({ where: { id: outputId, broadcastId } });
    if (!o) throw new NotFoundException({ code: 'output_not_found', message: 'Simulcast destination not found' });
    return o;
  }

  private async getOrThrow(id: string): Promise<Broadcast> {
    const b = await this.prisma.broadcast.findUnique({ where: { id } });
    if (!b) throw new NotFoundException({ code: 'broadcast_not_found', message: 'Broadcast not found' });
    return b;
  }

  private async ownedOrThrow(userId: string, id: string): Promise<Broadcast> {
    const b = await this.getOrThrow(id);
    if (b.creatorId !== userId) {
      throw new ForbiddenException({ code: 'forbidden', message: 'Not your broadcast' });
    }
    return b;
  }
}
