import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { UsersModule } from '../users/users.module';
import { TradersModule } from '../traders/traders.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';
import { PayoutsModule } from '../payouts/payouts.module';

@Module({
  imports: [UsersModule, TradersModule, NotificationsModule, WalletModule, PayoutsModule],
  providers: [AdminService],
  controllers: [AdminController],
})
export class AdminModule {}
