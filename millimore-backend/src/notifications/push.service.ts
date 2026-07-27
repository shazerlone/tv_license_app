import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Push delivery (FCM/APNs). Sending real pushes needs a Firebase service account
 * (FCM_SERVER_KEY) — a deliberate later step. Until then this logs intent; the
 * device-token registry (POST /devices) and the trigger points are already live,
 * so turning it on is config + one HTTP call, not a rewrite.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger('PushService');
  private readonly key?: string;

  constructor(config: ConfigService, private readonly prisma: PrismaService) {
    this.key = config.get<string>('FCM_SERVER_KEY') || undefined;
  }

  async sendToUser(userId: string, msg: { title: string; body?: string; data?: object }) {
    const devices = await this.prisma.device.findMany({
      where: { userId },
      select: { token: true, platform: true },
    });
    if (devices.length === 0) return;

    if (!this.key) {
      this.logger.debug(
        `[push:dev] → ${devices.length} device(s) of ${userId}: ${msg.title}`,
      );
      return;
    }
    // TODO(prod): POST to FCM (https://fcm.googleapis.com/fcm/send) with `this.key`.
    this.logger.log(`[push] would send to ${devices.length} device(s): ${msg.title}`);
  }
}
