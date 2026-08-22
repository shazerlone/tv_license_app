import { Module } from '@nestjs/common';
import { SubscriptionsService } from './subscriptions.service';
import { SubscriptionsController } from './subscriptions.controller';
import { TradersModule } from '../traders/traders.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TradersModule, NotificationsModule],
  providers: [SubscriptionsService],
  controllers: [SubscriptionsController],
})
export class SubscriptionsModule {}
