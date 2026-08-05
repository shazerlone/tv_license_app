import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeBus } from '../realtime/realtime.bus';
import { genId } from '../common/ids';
import { YoutubeService } from './youtube.service';

interface IngestState {
  liveChatId: string;
  pageToken?: string;
  timer?: NodeJS.Timeout;
  stopped: boolean;
}

/**
 * Pipes a creator's YouTube live chat into the in-app broadcast chat. Started
 * when a connected creator goes live, stopped when the broadcast ends. Each
 * YouTube message is stored (source="youtube") and fanned out over the WS
 * `broadcast:{id}` channel — appearing alongside native chat. Respects the API's
 * pollingIntervalMillis to stay within quota. In-process (per instance); no-op
 * when YouTube isn't configured or the creator isn't connected/live.
 */
@Injectable()
export class YoutubeIngestService implements OnModuleDestroy {
  private readonly log = new Logger('YoutubeIngest');
  private readonly active = new Map<string, IngestState>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly bus: RealtimeBus,
    private readonly youtube: YoutubeService,
  ) {}

  async start(broadcastId: string, userId: string): Promise<void> {
    if (!this.youtube.enabled || this.active.has(broadcastId)) return;
    const liveChatId = await this.youtube.resolveLiveChatId(userId).catch(() => null);
    if (!liveChatId) return; // creator not connected or not live on YouTube
    await this.prisma.broadcast.update({ where: { id: broadcastId }, data: { youtubeLiveChatId: liveChatId } }).catch(() => undefined);
    const state: IngestState = { liveChatId, stopped: false };
    this.active.set(broadcastId, state);
    this.log.log(`YouTube chat ingest started for ${broadcastId}`);
    void this.loop(broadcastId, userId, state);
  }

  stop(broadcastId: string): void {
    const s = this.active.get(broadcastId);
    if (!s) return;
    s.stopped = true;
    if (s.timer) clearTimeout(s.timer);
    this.active.delete(broadcastId);
  }

  private async loop(broadcastId: string, userId: string, state: IngestState): Promise<void> {
    if (state.stopped) return;
    let delay = 5000;
    try {
      const res = await this.youtube.pollChat(userId, state.liveChatId, state.pageToken);
      if (res) {
        state.pageToken = res.nextPageToken ?? state.pageToken;
        delay = Math.max(3000, res.pollingIntervalMillis);
        for (const m of res.messages) await this.forward(broadcastId, m.author, m.text);
      }
    } catch (e) {
      this.log.warn(`poll error (${broadcastId}): ${(e as Error).message}`);
    }
    if (!state.stopped) state.timer = setTimeout(() => void this.loop(broadcastId, userId, state), delay);
  }

  private async forward(broadcastId: string, author: string, text: string): Promise<void> {
    await this.prisma.broadcastChat.create({
      data: { id: genId('lc'), broadcastId, author, text, source: 'youtube', byHost: false },
    });
    this.bus.emitBroadcast(broadcastId, {
      ch: `broadcast:${broadcastId}`,
      type: 'chat',
      data: { author, text, source: 'youtube', byHost: false, createdAt: new Date().toISOString() },
    });
  }

  onModuleDestroy() {
    for (const id of [...this.active.keys()]) this.stop(id);
  }
}
