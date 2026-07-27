import { Module } from '@nestjs/common';
import { CreatorService } from './creator.service';
import { CreatorController } from './creator.controller';
import { CryptoModule } from '../common/crypto/crypto.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [CryptoModule, UsersModule],
  providers: [CreatorService],
  controllers: [CreatorController],
  exports: [CreatorService],
})
export class CreatorModule {}
