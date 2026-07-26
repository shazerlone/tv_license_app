import { Module } from '@nestjs/common';
import { BrokersService } from './brokers.service';
import { BrokersController } from './brokers.controller';

@Module({
  providers: [BrokersService],
  controllers: [BrokersController],
  exports: [BrokersService],
})
export class BrokersModule {}
