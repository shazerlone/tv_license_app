import { Module } from '@nestjs/common';
import { CreatorService } from './creator.service';
import { CreatorController } from './creator.controller';
import { CryptoModule } from '../common/crypto/crypto.module';

@Module({
  imports: [CryptoModule],
  providers: [CreatorService],
  controllers: [CreatorController],
  exports: [CreatorService],
})
export class CreatorModule {}
