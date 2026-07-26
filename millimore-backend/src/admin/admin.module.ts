import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { UsersModule } from '../users/users.module';
import { TradersModule } from '../traders/traders.module';

@Module({
  imports: [UsersModule, TradersModule],
  providers: [AdminService],
  controllers: [AdminController],
})
export class AdminModule {}
