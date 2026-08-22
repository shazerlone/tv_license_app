import { Module, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NotificationsModule } from '../notifications/notifications.module';
import { KYC_PROVIDER, KycProvider } from './kyc.types';
import { SumsubKycProvider } from './sumsub.kyc-provider';
import { ManualKycProvider } from './manual.kyc-provider';
import { KycService } from './kyc.service';
import { KycController } from './kyc.controller';

/**
 * KYC module. Picks Sumsub when SUMSUB_APP_TOKEN + SUMSUB_SECRET_KEY are set,
 * otherwise the manual provider (admin verifies in the dashboard). Swapping is
 * env, never code. Exports KycService so the admin module can drive decisions.
 */
@Module({
  imports: [NotificationsModule],
  providers: [
    KycService,
    {
      provide: KYC_PROVIDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService): KycProvider => {
        const token = config.get<string>('SUMSUB_APP_TOKEN');
        const secret = config.get<string>('SUMSUB_SECRET_KEY');
        if (token && secret) {
          Logger.log('KYC provider: sumsub', 'KycModule');
          return new SumsubKycProvider(
            token,
            secret,
            config.get<string>('SUMSUB_LEVEL_NAME', 'basic-kyc-level'),
          );
        }
        Logger.log('KYC provider: manual (set SUMSUB_* to enable Sumsub)', 'KycModule');
        return new ManualKycProvider();
      },
    },
  ],
  controllers: [KycController],
  exports: [KycService],
})
export class KycModule {}
