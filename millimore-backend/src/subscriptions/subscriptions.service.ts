import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TradersService } from '../traders/traders.service';
import { TraderDto } from '../traders/dto/trader.dto';

@Injectable()
export class SubscriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly traders: TradersService,
  ) {}

  async subscribe(userId: string, traderId: string): Promise<void> {
    await this.traders.getEntityOrThrow(traderId);
    await this.prisma.subscription.upsert({
      where: { userId_traderId: { userId, traderId } },
      update: {},
      create: { userId, traderId },
    });
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
