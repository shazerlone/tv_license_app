import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { SetupService } from './setup.service';
import { SetupController } from './setup.controller';

@Module({
  imports: [WalletModule, NotificationsModule],
  providers: [SetupService],
  controllers: [SetupController],
})
export class SetupModule {}
