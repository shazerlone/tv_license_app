import { Module } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { SettlementService } from './settlement.service';
import { DepositsService } from './deposits.service';
import { WalletController } from './wallet.controller';
import { DepositsController } from './deposits.controller';

/**
 * The money layer: wallet ledger, deposits, and copy settlement. PrismaModule
 * and ConfigModule are global, so nothing else is imported here. Exports the
 * services other modules settle/read through (copy, creator, admin, payouts).
 */
@Module({
  providers: [WalletService, SettlementService, DepositsService],
  controllers: [WalletController, DepositsController],
  exports: [WalletService, SettlementService],
})
export class WalletModule {}
