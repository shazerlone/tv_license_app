import { Global, Module } from '@nestjs/common';
import { PricesService } from './prices.service';
import { MarketFeedService } from './market-feed.service';
import { MarketController } from './market.controller';

// Global so the copy engine and the WS gateway share the one price source.
@Global()
@Module({
  providers: [PricesService, MarketFeedService],
  controllers: [MarketController],
  exports: [PricesService],
})
export class MarketModule {}
