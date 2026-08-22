import { Global, Module, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MT_BRIDGE, MtBridge } from './mt.types';
import { SyntheticMtBridge } from './synthetic-mt.bridge';
import { MetaApiMtBridge } from './metaapi-mt.bridge';

/**
 * Global MT bridge provider. Chooses the live provider when BROKER_BRIDGE_URL
 * is configured, otherwise the synthetic one. Consumers inject the MT_BRIDGE
 * token and depend only on the MtBridge interface — swapping providers is env,
 * never code (contract §8, CLAUDE.md portability guardrails).
 */
@Global()
@Module({
  providers: [
    {
      provide: MT_BRIDGE,
      inject: [ConfigService],
      useFactory: (config: ConfigService): MtBridge => {
        const url = config.get<string>('BROKER_BRIDGE_URL');
        if (url) {
          Logger.log(`MT bridge: live (${url})`, 'MtModule');
          return new MetaApiMtBridge(url, config.get<string>('BROKER_BRIDGE_TOKEN'));
        }
        Logger.log('MT bridge: synthetic (set BROKER_BRIDGE_URL to go live)', 'MtModule');
        return new SyntheticMtBridge();
      },
    },
  ],
  exports: [MT_BRIDGE],
})
export class MtModule {}
