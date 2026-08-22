import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { EmailVerificationService } from './email-verification.service';
import { UsersController } from './users.controller';

@Module({
  providers: [UsersService, EmailVerificationService],
  controllers: [UsersController],
  exports: [UsersService, EmailVerificationService],
})
export class UsersModule {}
