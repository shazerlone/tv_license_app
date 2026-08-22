import { Controller, Get, HttpCode, HttpStatus, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { AnnouncementsService } from './announcements.service';
import { AnnouncementFeedDto } from './dto/announcement.dto';

@ApiTags('announcements')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}

  @Get()
  @ApiOperation({ summary: 'Active announcements for me (bell feed) + unread count' })
  @ApiOkResponse({ type: AnnouncementFeedDto })
  feed(@CurrentUser() user: AuthUser): Promise<AnnouncementFeedDto> {
    return this.announcements.listForUser(user.userId, user.role);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark an announcement read / acknowledged' })
  read(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.announcements.markRead(user.userId, id);
  }
}
