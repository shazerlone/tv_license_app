import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TradersService } from '../traders/traders.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TraderDto } from '../traders/dto/trader.dto';

@Injectable()
export class SubscriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly traders: TradersService,
    private readonly notifications: NotificationsService,
  ) {}

  async subscribe(userId: string, traderId: string): Promise<void> {
    const trader = await this.traders.getEntityOrThrow(traderId);
    // Detect a genuinely new subscription so we don't re-notify on repeat calls.
    const existing = await this.prisma.subscription.findUnique({
      where: { userId_traderId: { userId, traderId } },
      select: { userId: true },
    });
    await this.prisma.subscription.upsert({
      where: { userId_traderId: { userId, traderId } },
      update: {},
      create: { userId, traderId },
    });
    if (!existing && trader.userId && trader.userId !== userId) {
      try {
        const actor = await this.prisma.user.findUnique({ where: { id: userId }, select: { name: true } });
        const actorName = actor?.name ?? 'Someone';
        await this.notifications.pushEvent(trader.userId, 'social.subscribe', `${actorName} subscribed to you`, {
          data: { actorName, traderId },
        });
      } catch {
        /* notifications are best-effort */
      }
    }
  }

  async unsubscribe(userId: string, traderId: string): Promise<void> {
    await this.prisma.subscription.deleteMany({ where: { userId, traderId } });
  }

  async list(userId: string): Promise<TraderDto[]> {
    const subs = await this.prisma.subscription.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { trader: true },
    });
    return subs.map((s) => this.traders.toDto(s.trader));
  }

  async setNotify(userId: string, traderId: string, on: boolean): Promise<void> {
    const sub = await this.prisma.subscription.findUnique({
      where: { userId_traderId: { userId, traderId } },
    });
    if (!sub) {
      throw new NotFoundException({
        code: 'subscription_not_found',
        message: 'Subscribe to this trader first',
      });
    }
    await this.prisma.subscription.update({
      where: { userId_traderId: { userId, traderId } },
      data: { notify: on },
    });
  }
}
