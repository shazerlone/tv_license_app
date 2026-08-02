import { Global, Module } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { ConfigController } from './config.controller';

/** Global so any module (settlement, deposits, payouts, copy) can read settings. */
@Global()
@Module({
  providers: [SettingsService],
  controllers: [ConfigController],
  exports: [SettingsService],
})
export class SettingsModule {}
