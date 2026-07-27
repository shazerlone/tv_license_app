import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { Broadcast } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CloudflareService } from './cloudflare.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeBus } from '../realtime/realtime.bus';
import { genId } from '../common/ids';
import {
  BroadcastDto,
  CreateBroadcastDto,
  LiveChatMessageDto,
  BroadcastSummaryDto,
} from './dto/broadcast.dto';

@Injectable()
export class BroadcastsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cf: CloudflareService,
    private readonly notifications: NotificationsService,
    private readonly bus: RealtimeBus,
  ) {}

  private toDto(b: Broadcast, owner = false): BroadcastDto {
    return {
      id: b.id,
      creatorId: b.creatorId,
      title: b.title,
      phase: b.phase,
      // Ingest credentials are only exposed to the broadcasting creator.
      ingestUrl: owner ? b.ingestUrl : undefined,
      streamKey: owner ? b.streamKey : undefined,
      hlsUrl: b.hlsUrl,
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
    const endedAt = new Date();
    await this.prisma.broadcast.update({
      where: { id },
      data: { phase: 'ended', endedAt, viewers: 0 },
    });
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
    return rows.map((b) => this.toDto(b, false));
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
