import { Global, Module } from '@nestjs/common';
import { CryptoModule } from '../common/crypto/crypto.module';
import { TwofaService } from './twofa.service';
import { TwofaController } from './twofa.controller';

/** Global so AuthService can verify the login second factor without a cycle. */
@Global()
@Module({
  imports: [CryptoModule],
  providers: [TwofaService],
  controllers: [TwofaController],
  exports: [TwofaService],
})
export class TwofaModule {}
