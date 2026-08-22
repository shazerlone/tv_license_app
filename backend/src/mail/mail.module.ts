import { Global, Module } from '@nestjs/common';
import { MailService } from './mail.service';

// Global: password reset, security alerts and (later) receipts all reuse it.
@Global()
@Module({
  providers: [MailService],
  exports: [MailService],
})
export class MailModule {}
