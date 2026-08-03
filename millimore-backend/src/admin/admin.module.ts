import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AnalyticsService } from './analytics.service';
import { AdminController } from './admin.controller';
import { UsersModule } from '../users/users.module';
import { TradersModule } from '../traders/traders.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';
import { PayoutsModule } from '../payouts/payouts.module';
import { KycModule } from '../kyc/kyc.module';

@Module({
  imports: [UsersModule, TradersModule, NotificationsModule, WalletModule, PayoutsModule, KycModule],
  providers: [AdminService, AnalyticsService],
  controllers: [AdminController],
})
export class AdminModule {}
