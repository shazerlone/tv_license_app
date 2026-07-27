import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WebSocket, WebSocketServer } from 'ws';
import type { Server as HttpServer } from 'http';
import type { CopyPosition } from '@prisma/client';
import { PricesService, PriceMap } from '../market/prices.service';
import { CopyService } from '../copy/copy.service';

interface Client extends WebSocket {
  userId?: string;
  subs?: Set<string>;
  isAlive?: boolean;
  positions?: CopyPosition[];
  positionsLoadedAt?: number;
}

const PORTFOLIO_RELOAD_MS = 5000;

/**
 * Realtime WebSocket gateway (contract §5). Protocol:
 *   connect:  wss://…/v1/ws?token=<JWT>
 *   client →  { "op":"subscribe"|"unsubscribe", "channels":["prices","portfolio",…] }
 *   server →  { "ch":"prices", "data": { "XAU/USD":2015.4, … } }         (~1/sec)
 *             { "ch":"portfolio", "type":"position", "data": CopyPosition } (live P/L)
 *
 * Single-instance today. To scale horizontally, publish the price tick to Redis
 * and have each instance's gateway subscribe (see ARCHITECTURE.md) — the client
 * protocol is unchanged.
 */
@Injectable()
export class RealtimeGateway {
  private readonly logger = new Logger('RealtimeGateway');
  private wss?: WebSocketServer;

  constructor(
    private readonly jwt: JwtService,
    private readonly prices: PricesService,
    private readonly copy: CopyService,
  ) {}

  bind(server: HttpServer) {
    if (this.wss) return;
    this.wss = new WebSocketServer({ server, path: '/v1/ws' });

    this.wss.on('connection', (socket: Client, req) => {
      const userId = this.authenticate(req.url);
      if (!userId) {
        socket.close(1008, 'unauthorized');
        return;
      }
      socket.userId = userId;
      socket.subs = new Set();
      socket.isAlive = true;

      socket.on('pong', () => (socket.isAlive = true));
      socket.on('message', (raw) => this.onMessage(socket, raw.toString()));
      socket.on('error', () => socket.terminate());

      socket.send(JSON.stringify({ ch: 'system', type: 'connected', data: { ok: true } }));
    });

    // One shared price tick fans out to all subscribers.
    this.prices.on('tick', (snapshot: PriceMap) => this.broadcastTick(snapshot));

    // Heartbeat — drop dead sockets.
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
      const payload = this.jwt.verify(token) as { sub: string };
      return payload.sub ?? null;
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
      for (const ch of msg.channels) socket.subs?.add(ch);
      // Immediate priming so the UI isn't blank until the next tick.
      if (socket.subs?.has('prices')) {
        socket.send(JSON.stringify({ ch: 'prices', data: this.prices.snapshot() }));
      }
      if (socket.subs?.has('portfolio')) {
        await this.loadPositions(socket);
        this.sendPortfolio(socket);
      }
    } else if (msg.op === 'unsubscribe') {
      for (const ch of msg.channels) socket.subs?.delete(ch);
    }
  }

  private async loadPositions(socket: Client) {
    if (!socket.userId) return;
    socket.positions = await this.copy.activePositions(socket.userId);
    socket.positionsLoadedAt = Date.now();
  }

  private sendPortfolio(socket: Client) {
    for (const p of socket.positions ?? []) {
      socket.send(
        JSON.stringify({ ch: 'portfolio', type: 'position', data: this.copy.toPositionDto(p) }),
      );
    }
  }

  private broadcastTick(snapshot: PriceMap) {
    if (!this.wss) return;
    const now = Date.now();
    this.wss.clients.forEach(async (c: Client) => {
      if (c.readyState !== WebSocket.OPEN || !c.subs) return;
      if (c.subs.has('prices')) {
        c.send(JSON.stringify({ ch: 'prices', data: snapshot }));
      }
      if (c.subs.has('portfolio')) {
        if (!c.positionsLoadedAt || now - c.positionsLoadedAt > PORTFOLIO_RELOAD_MS) {
          await this.loadPositions(c);
        }
        this.sendPortfolio(c);
      }
    });
  }
}
