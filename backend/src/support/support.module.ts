import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { SupportService } from './support.service';
import { AnnouncementsService } from './announcements.service';
import { SupportController } from './support.controller';
import { AnnouncementsController } from './announcements.controller';

/**
 * Support (helpdesk tickets) + Announcements (bell feed). Exports both services
 * so the admin module can drive replies, status, and announcement CRUD.
 */
@Module({
  imports: [NotificationsModule],
  providers: [SupportService, AnnouncementsService],
  controllers: [SupportController, AnnouncementsController],
  exports: [SupportService, AnnouncementsService],
})
export class SupportModule {}
