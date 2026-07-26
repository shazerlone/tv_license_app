import { Module } from '@nestjs/common';
import { TradersService } from './traders.service';
import { TradersController } from './traders.controller';

@Module({
  providers: [TradersService],
  controllers: [TradersController],
  exports: [TradersService],
})
export class TradersModule {}
