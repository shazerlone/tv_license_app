import { Injectable } from '@nestjs/common';
import { Notification } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';
import { NotificationDto, RegisterDeviceDto } from './dto/notification.dto';
import { RealtimeBus } from '../realtime/realtime.bus';
import { PushService } from './push.service';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bus: RealtimeBus,
    private readonly push: PushService,
  ) {}

  /**
   * One call to notify a user everywhere: persist (for the notification center),
   * deliver live over the WS `user` channel, and fire a push. Used by creator
   * approval, trade events, live-started, etc.
   */
  async pushEvent(
    userId: string,
    type: string,
    title: string,
    opts: { body?: string; data?: object; push?: boolean } = {},
  ): Promise<void> {
    await this.create(userId, type, title, opts.body, opts.data);
    this.bus.emitUser(userId, { ch: 'user', type, data: opts.data ?? { title } });
    if (opts.push !== false) {
      await this.push.sendToUser(userId, { title, body: opts.body, data: opts.data });
    }
  }

  private toDto(n: Notification): NotificationDto {
    return {
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: n.data ?? undefined,
      createdAt: n.createdAt.toISOString(),
      read: n.read,
    };
  }

  async list(userId: string): Promise<NotificationDto[]> {
    const rows = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((n) => this.toDto(n));
  }

  async markRead(userId: string, ids: string[]): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, id: { in: ids } },
      data: { read: true },
    });
  }

  /**
   * Create a notification for a user. Reusable by any module that needs to
   * notify (creator approval, and — from milestone 4/5 — trade/live events).
   */
  async create(userId: string, type: string, title: string, body?: string, data?: object) {
    return this.prisma.notification.create({
      data: { id: genId('n'), userId, type, title, body, data: data as any },
    });
  }

  // ── push devices ────────────────────────────────────────────────────
  async registerDevice(userId: string, dto: RegisterDeviceDto): Promise<void> {
    await this.prisma.device.upsert({
      where: { token: dto.token },
      update: { userId, platform: dto.platform, appVersion: dto.appVersion },
      create: {
        token: dto.token,
        userId,
        platform: dto.platform,
        appVersion: dto.appVersion,
      },
    });
  }

  async removeDevice(userId: string, token: string): Promise<void> {
    await this.prisma.device.deleteMany({ where: { userId, token } });
  }
}
