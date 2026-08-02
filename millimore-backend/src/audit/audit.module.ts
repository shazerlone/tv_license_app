import { Global, Module } from '@nestjs/common';
import { AuditService } from './audit.service';

/** Global so any privileged handler can record an audit row. */
@Global()
@Module({
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}
