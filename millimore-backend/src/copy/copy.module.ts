import { Module } from '@nestjs/common';
import { CopyService } from './copy.service';
import { CopyController } from './copy.controller';

@Module({
  providers: [CopyService],
  controllers: [CopyController],
  exports: [CopyService],
})
export class CopyModule {}
