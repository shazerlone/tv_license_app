import { Injectable } from '@nestjs/common';
import { Notification } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { genId } from '../common/ids';
import { NotificationDto, RegisterDeviceDto } from './dto/notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

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
