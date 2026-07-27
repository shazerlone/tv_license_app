import { Module } from '@nestjs/common';
import { BroadcastsService } from './broadcasts.service';
import { BroadcastsController } from './broadcasts.controller';
import { CloudflareService } from './cloudflare.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  providers: [BroadcastsService, CloudflareService],
  controllers: [BroadcastsController],
})
export class BroadcastsModule {}
