import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';
import { PayoutsService } from './payouts.service';
import { PayoutsController } from './payouts.controller';

/**
 * Withdrawals from the wallet. Imports NotificationsModule (notify the user on
 * approve/reject) and WalletModule (hold/refund funds). Exports PayoutsService
 * so the admin module can list/approve/reject.
 */
@Module({
  imports: [NotificationsModule, WalletModule],
  providers: [PayoutsService],
  controllers: [PayoutsController],
  exports: [PayoutsService],
})
export class PayoutsModule {}
