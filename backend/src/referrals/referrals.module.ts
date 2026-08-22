import { Global, Module } from '@nestjs/common';
import { ReferralsService } from './referrals.service';
import { ReferralsController } from './referrals.controller';

/**
 * Referral / affiliate module. Global so auth (register) can resolve a code and
 * admin can read top referrers, without import cycles. Earnings are credited by
 * SettlementService (revenue share) and DepositsService (signup bonus).
 */
@Global()
@Module({
  providers: [ReferralsService],
  controllers: [ReferralsController],
  exports: [ReferralsService],
})
export class ReferralsModule {}
