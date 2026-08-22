import { BadRequestException, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PricesService, PriceMap } from '../market/prices.service';
import { NotificationsService } from '../notifications/notifications.service';
import { MailService } from '../mail/mail.service';
import { CreatePriceAlertDto, PriceAlertDto } from './dto/alert.dto';
import { genId } from '../common/ids';
import type { PriceAlert } from '@prisma/client';

const MAX_ACTIVE_ALERTS = 50;
const EVAL_INTERVAL_MS = 2000; // don't hammer the DB on every 1s tick

/**
 * Price alerts (contract §alerts). One-shot alerts that fire when a symbol's
 * live price crosses the user's target. Composes the price engine (trigger),
 * notifications (push + in-app + WS) and mail (optional email) built earlier.
 *
 * Multi-instance safe: the tick handler runs on every instance, but firing is
 * gated by an atomic `updateMany(active → triggered)` — only the instance whose
 * update flips the row sends the notification, so no duplicates.
 */
@Injectable()
export class AlertsService implements OnModuleInit {
  private readonly logger = new Logger('AlertsService');
  private lastEval = 0;
  private evaluating = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly prices: PricesService,
    private readonly notifications: NotificationsService,
    private readonly mail: MailService,
  ) {}

  onModuleInit() {
    this.prices.on('tick', (snapshot: PriceMap) => {
      const now = Date.now();
      if (now - this.lastEval < EVAL_INTERVAL_MS || this.evaluating) return;
      this.lastEval = now;
      void this.evaluate(snapshot);
    });
  }

  // ── CRUD ────────────────────────────────────────────────────────────
  async list(userId: string, status?: string): Promise<PriceAlertDto[]> {
    const rows = await this.prisma.priceAlert.findMany({
      where: { userId, ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => this.toDto(r));
  }

  async create(userId: string, dto: CreatePriceAlertDto): Promise<PriceAlertDto> {
    const symbol = dto.symbol.toUpperCase().trim();
    if (!this.prices.symbols().includes(symbol)) {
      throw new BadRequestException({ code: 'unknown_symbol', message: `Unknown symbol ${symbol}.` });
    }
    const active = await this.prisma.priceAlert.count({ where: { userId, status: 'active' } });
    if (active >= MAX_ACTIVE_ALERTS) {
      throw new BadRequestException({ code: 'too_many_alerts', message: `You can have at most ${MAX_ACTIVE_ALERTS} active alerts.` });
    }
    // Reject an alert that's already satisfied — it would fire immediately and
    // isn't what the user means. Guide them to a target on the right side.
    const price = this.prices.price(symbol);
    if (price != null && this.isMet(dto.direction, price, dto.targetPrice)) {
      throw new BadRequestException({
        code: 'alert_already_met',
        message: `${symbol} is already ${dto.direction} ${dto.targetPrice} (now ${price}). Pick a target on the other side.`,
      });
    }
    const row = await this.prisma.priceAlert.create({
      data: {
        id: genId('pa'),
        userId,
        symbol,
        direction: dto.direction,
        targetPrice: dto.targetPrice,
        note: dto.note,
        notifyEmail: dto.notifyEmail ?? false,
      },
    });
    return this.toDto(row);
  }

  async cancel(userId: string, id: string): Promise<void> {
    const row = await this.prisma.priceAlert.findFirst({ where: { id, userId } });
    if (!row) throw new NotFoundException({ code: 'alert_not_found', message: 'Alert not found.' });
    if (row.status === 'active') {
      await this.prisma.priceAlert.update({ where: { id }, data: { status: 'cancelled' } });
    }
  }

  // ── evaluation ──────────────────────────────────────────────────────
  private isMet(direction: string, price: number, target: number): boolean {
    return direction === 'above' ? price >= target : price <= target;
  }

  private async evaluate(snapshot: PriceMap) {
    this.evaluating = true;
    try {
      const symbols = Object.keys(snapshot);
      if (symbols.length === 0) return;
      const candidates = await this.prisma.priceAlert.findMany({
        where: { status: 'active', symbol: { in: symbols } },
      });
      for (const a of candidates) {
        const price = snapshot[a.symbol];
        if (price == null || !this.isMet(a.direction, price, a.targetPrice)) continue;
        // Atomic single-fire: only the instance that flips active→triggered notifies.
        const res = await this.prisma.priceAlert.updateMany({
          where: { id: a.id, status: 'active' },
          data: { status: 'triggered', triggeredAt: new Date(), triggeredPrice: price },
        });
        if (res.count === 1) await this.fire(a, price);
      }
    } catch (err) {
      this.logger.warn(`alert evaluation failed: ${String(err)}`);
    } finally {
      this.evaluating = false;
    }
  }

  private async fire(alert: PriceAlert, price: number) {
    const title = `${alert.symbol} is ${alert.direction} ${alert.targetPrice}`;
    const body = `${alert.symbol} just traded at ${price} (your alert: ${alert.direction} ${alert.targetPrice}).`;
    await this.notifications.pushEvent(alert.userId, 'price.alert', title, {
      body,
      data: { alertId: alert.id, symbol: alert.symbol, direction: alert.direction, targetPrice: alert.targetPrice, price },
    });
    if (alert.notifyEmail) {
      const user = await this.prisma.user.findUnique({ where: { id: alert.userId }, select: { email: true, name: true } });
      if (user?.email) {
        void this.mail.sendPriceAlert(user.email, {
          name: user.name ?? undefined,
          symbol: alert.symbol,
          direction: alert.direction,
          targetPrice: alert.targetPrice,
          price,
        });
      }
    }
  }

  // ── mapper ──────────────────────────────────────────────────────────
  private toDto(r: PriceAlert): PriceAlertDto {
    return {
      id: r.id,
      symbol: r.symbol,
      direction: r.direction,
      targetPrice: r.targetPrice,
      note: r.note,
      notifyEmail: r.notifyEmail,
      status: r.status,
      triggeredAt: r.triggeredAt ? r.triggeredAt.toISOString() : null,
      triggeredPrice: r.triggeredPrice,
      createdAt: r.createdAt.toISOString(),
    };
  }
}
