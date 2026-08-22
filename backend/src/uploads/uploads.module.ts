import { Module } from '@nestjs/common';
import { UploadsController } from './uploads.controller';
import { StorageService } from './storage.service';

@Module({
  providers: [StorageService],
  controllers: [UploadsController],
  exports: [StorageService],
})
export class UploadsModule {}
