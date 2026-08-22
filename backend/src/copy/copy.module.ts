import { Module } from '@nestjs/common';
import { CopyService } from './copy.service';
import { CopyController } from './copy.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';

@Module({
  imports: [NotificationsModule, WalletModule],
  providers: [CopyService],
  controllers: [CopyController],
  exports: [CopyService],
})
export class CopyModule {}
