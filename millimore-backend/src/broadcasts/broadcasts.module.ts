import { Module } from '@nestjs/common';
import { BroadcastsService } from './broadcasts.service';
import { BroadcastsController } from './broadcasts.controller';
import { CloudflareService } from './cloudflare.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { CryptoModule } from '../common/crypto/crypto.module';

@Module({
  imports: [NotificationsModule, CryptoModule],
  providers: [BroadcastsService, CloudflareService],
  controllers: [BroadcastsController],
})
export class BroadcastsModule {}
