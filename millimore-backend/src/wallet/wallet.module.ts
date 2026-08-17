import { Module } from '@nestjs/common';
import { CryptoModule } from '../common/crypto/crypto.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletService } from './wallet.service';
import { SettlementService } from './settlement.service';
import { DepositsService } from './deposits.service';
import { CryptoDepositService } from './crypto/crypto-deposit.service';
import { CryptoAddressService } from './crypto/crypto-address.service';
import { SweepService } from './crypto/sweep.service';
import { PayoutMethodsService } from './payout-methods.service';
import { TransactionsService } from './transactions.service';
import { WalletController } from './wallet.controller';
import { DepositsController } from './deposits.controller';
import { DepositsWebhookController } from './deposits.webhook.controller';
import { PayoutMethodsController } from './payout-methods.controller';

/**
 * The money layer: wallet ledger, deposits, saved payout methods, transaction
 * history, and copy settlement. PrismaModule, ConfigModule and SettingsModule
 * are global. Exports the services other modules settle/read through (copy,
 * creator, admin, payouts).
 */
@Module({
  imports: [CryptoModule, NotificationsModule],
  providers: [
    WalletService,
    SettlementService,
    DepositsService,
    CryptoDepositService,
    CryptoAddressService,
    SweepService,
    PayoutMethodsService,
    TransactionsService,
  ],
  controllers: [WalletController, DepositsController, DepositsWebhookController, PayoutMethodsController],
  exports: [
    WalletService,
    SettlementService,
    DepositsService,
    SweepService,
    PayoutMethodsService,
    TransactionsService,
  ],
})
export class WalletModule {}
