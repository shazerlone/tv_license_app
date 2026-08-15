import { Module } from '@nestjs/common';
import { CryptoModule } from '../common/crypto/crypto.module';
import { WalletService } from './wallet.service';
import { SettlementService } from './settlement.service';
import { DepositsService } from './deposits.service';
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
  imports: [CryptoModule],
  providers: [
    WalletService,
    SettlementService,
    DepositsService,
    PayoutMethodsService,
    TransactionsService,
  ],
  controllers: [WalletController, DepositsController, DepositsWebhookController, PayoutMethodsController],
  exports: [
    WalletService,
    SettlementService,
    DepositsService,
    PayoutMethodsService,
    TransactionsService,
  ],
})
export class WalletModule {}
