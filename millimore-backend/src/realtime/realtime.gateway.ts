import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WebSocket, WebSocketServer } from 'ws';
import type { Server as HttpServer } from 'http';
import type { CopyPosition } from '@prisma/client';
import { PricesService, PriceMap } from '../market/prices.service';
import { CopyService } from '../copy/copy.service';
import { RealtimeBus } from './realtime.bus';
import { PrismaService } from '../prisma/prisma.service';

interface Client extends WebSocket {
  userId?: string;
  subs?: Set<string>;
  isAlive?: boolean;
  positions?: CopyPosition[];
  positionsLoadedAt?: number;
}

const PORTFOLIO_RELOAD_MS = 5000;
const BROADCAST_PREFIX = 'broadcast:';

/**
 * Realtime WebSocket gateway (contract §5). Protocol:
 *   connect:  wss://…/v1/ws?token=<JWT>
 *   client →  { "op":"subscribe"|"unsubscribe", "channels":["prices","portfolio","user","broadcast:b_1"] }
 *   server →  { "ch":"prices", "data":{…} }                                   (~1/sec)
 *             { "ch":"portfolio", "type":"position", "data": CopyPosition }    (live P/L)
 *             { "ch":"user", "type":"trade.opened|trade.closed|creator.status|…", "data":… }
 *             { "ch":"broadcast:b_1", "type":"chat|viewers|reaction|trade", "data":… }
 *
 * Producers publish via RealtimeBus; swap that for Redis pub/sub to scale
 * horizontally without changing this protocol (see ARCHITECTURE.md).
 */
@Injectable()
export class RealtimeGateway {
  private readonly logger = new Logger('RealtimeGateway');
  private wss?: WebSocketServer;

  constructor(
    private readonly jwt: JwtService,
    private readonly prices: PricesService,
    private readonly copy: CopyService,
    private readonly bus: RealtimeBus,
    private readonly prisma: PrismaService,
  ) {}

  bind(server: HttpServer) {
    if (this.wss) return;
    this.wss = new WebSocketServer({ server, path: '/v1/ws' });

    this.wss.on('connection', (socket: Client, req) => {
      const userId = this.authenticate(req.url);
      if (!userId) return socket.close(1008, 'unauthorized');
      socket.userId = userId;
      socket.subs = new Set();
      socket.isAlive = true;
      socket.on('pong', () => (socket.isAlive = true));
      socket.on('message', (raw) => this.onMessage(socket, raw.toString()));
      socket.on('close', () => this.onClose(socket));
      socket.on('error', () => socket.terminate());
      socket.send(JSON.stringify({ ch: 'system', type: 'connected', data: { ok: true } }));
    });

    // Price ticks fan out to prices/portfolio subscribers.
    this.prices.on('tick', (snapshot: PriceMap) => this.broadcastTick(snapshot));
    // Producer events (trade.*, creator.status, chat, viewers, reactions).
    this.bus.on('user', ({ userId, payload }) => this.forwardUser(userId, payload));
    this.bus.on('broadcast', ({ broadcastId, payload }) =>
      this.forwardBroadcast(broadcastId, payload),
    );
    this.bus.on('channel', ({ channel, payload }) => this.forwardChannel(channel, payload));

    const hb = setInterval(() => {
      this.wss?.clients.forEach((c: Client) => {
        if (c.isAlive === false) return c.terminate();
        c.isAlive = false;
        c.ping();
      });
    }, 30000);
    hb.unref?.();

    this.logger.log('WebSocket gateway listening at /v1/ws');
  }

  private authenticate(url?: string): string | null {
    try {
      const q = new URLSearchParams((url ?? '').split('?')[1] ?? '');
      const token = q.get('token');
      if (!token) return null;
      return (this.jwt.verify(token) as { sub: string }).sub ?? null;
    } catch {
      return null;
    }
  }

  private async onMessage(socket: Client, raw: string) {
    let msg: { op?: string; channels?: string[] };
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (!Array.isArray(msg.channels)) return;

    if (msg.op === 'subscribe') {
      for (const ch of msg.channels) {
        socket.subs?.add(ch);
        if (ch.startsWith(BROADCAST_PREFIX)) await this.onJoinBroadcast(ch.slice(BROADCAST_PREFIX.length));
      }
      if (socket.subs?.has('prices')) {
        socket.send(JSON.stringify({ ch: 'prices', data: this.prices.snapshot() }));
      }
      if (socket.subs?.has('portfolio')) {
        await this.loadPositions(socket);
        this.sendPortfolio(socket);
      }
    } else if (msg.op === 'unsubscribe') {
      for (const ch of msg.channels) {
        socket.subs?.delete(ch);
        if (ch.startsWith(BROADCAST_PREFIX)) await this.onLeaveBroadcast(ch.slice(BROADCAST_PREFIX.length));
      }
    }
  }

  private onClose(socket: Client) {
    for (const ch of socket.subs ?? []) {
      if (ch.startsWith(BROADCAST_PREFIX)) this.onLeaveBroadcast(ch.slice(BROADCAST_PREFIX.length));
    }
  }

  // ── portfolio ───────────────────────────────────────────────────────
  private async loadPositions(socket: Client) {
    if (!socket.userId) return;
    socket.positions = await this.copy.activePositions(socket.userId);
    socket.positionsLoadedAt = Date.now();
  }

  private sendPortfolio(socket: Client) {
    for (const p of socket.positions ?? []) {
      socket.send(JSON.stringify({ ch: 'portfolio', type: 'position', data: this.copy.toPositionDto(p) }));
    }
  }

  private broadcastTick(snapshot: PriceMap) {
    if (!this.wss) return;
    const now = Date.now();
    this.wss.clients.forEach(async (c: Client) => {
      if (c.readyState !== WebSocket.OPEN || !c.subs) return;
      if (c.subs.has('prices')) c.send(JSON.stringify({ ch: 'prices', data: snapshot }));
      if (c.subs.has('portfolio')) {
        if (!c.positionsLoadedAt || now - c.positionsLoadedAt > PORTFOLIO_RELOAD_MS) {
          await this.loadPositions(c);
        }
        this.sendPortfolio(c);
      }
    });
  }

  // ── producer event forwarding ───────────────────────────────────────
  private forwardUser(userId: string, payload: unknown) {
    this.wss?.clients.forEach((c: Client) => {
      if (c.readyState === WebSocket.OPEN && c.userId === userId && c.subs?.has('user')) {
        c.send(JSON.stringify(payload));
      }
    });
  }

  private forwardBroadcast(broadcastId: string, payload: unknown) {
    const ch = `${BROADCAST_PREFIX}${broadcastId}`;
    this.wss?.clients.forEach((c: Client) => {
      if (c.readyState === WebSocket.OPEN && c.subs?.has(ch)) c.send(JSON.stringify(payload));
    });
  }

  /** Forward to subscribers of an exact channel name (e.g. `pair:XAU/USD`). */
  private forwardChannel(channel: string, payload: unknown) {
    this.wss?.clients.forEach((c: Client) => {
      if (c.readyState === WebSocket.OPEN && c.subs?.has(channel)) c.send(JSON.stringify(payload));
    });
  }

  // ── broadcast viewers ───────────────────────────────────────────────
  private viewerCount(broadcastId: string): number {
    const ch = `${BROADCAST_PREFIX}${broadcastId}`;
    let n = 0;
    this.wss?.clients.forEach((c: Client) => {
      if (c.readyState === WebSocket.OPEN && c.subs?.has(ch)) n++;
    });
    return n;
  }

  private async onJoinBroadcast(broadcastId: string) {
    const viewers = this.viewerCount(broadcastId); // subs already include the joiner
    await this.persistViewers(broadcastId, viewers);
    this.forwardBroadcast(broadcastId, { ch: `${BROADCAST_PREFIX}${broadcastId}`, type: 'viewers', data: { viewers } });
  }

  private async onLeaveBroadcast(broadcastId: string) {
    const viewers = Math.max(0, this.viewerCount(broadcastId));
    await this.persistViewers(broadcastId, viewers);
    this.forwardBroadcast(broadcastId, { ch: `${BROADCAST_PREFIX}${broadcastId}`, type: 'viewers', data: { viewers } });
  }

  private async persistViewers(broadcastId: string, viewers: number) {
    try {
      const b = await this.prisma.broadcast.findUnique({
        where: { id: broadcastId },
        select: { peakViewers: true },
      });
      if (!b) return;
      await this.prisma.broadcast.update({
        where: { id: broadcastId },
        data: { viewers, peakViewers: Math.max(b.peakViewers, viewers) },
      });
    } catch {
      /* broadcast may not exist yet */
    }
  }
}
