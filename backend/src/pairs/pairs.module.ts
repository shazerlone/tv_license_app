import { Module } from '@nestjs/common';
import { PairsService } from './pairs.service';
import { PairsController } from './pairs.controller';

@Module({
  providers: [PairsService],
  controllers: [PairsController],
  exports: [PairsService],
})
export class PairsModule {}
