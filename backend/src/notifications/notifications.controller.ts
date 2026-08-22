import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { NotificationDto, MarkReadDto, RegisterDeviceDto } from './dto/notification.dto';

@ApiTags('notifications')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  @Get('notifications')
  @ApiOperation({ summary: 'List my notifications (contract §4.12)' })
  @ApiOkResponse({ type: [NotificationDto] })
  list(@CurrentUser() u: AuthUser): Promise<NotificationDto[]> {
    return this.svc.list(u.userId);
  }

  @Post('notifications/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mark notifications read (contract §4.12)' })
  async markRead(@CurrentUser() u: AuthUser, @Body() dto: MarkReadDto): Promise<void> {
    await this.svc.markRead(u.userId, dto.ids);
  }

  @Post('devices')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Register a push device token (contract §4.12)' })
  async register(@CurrentUser() u: AuthUser, @Body() dto: RegisterDeviceDto): Promise<void> {
    await this.svc.registerDevice(u.userId, dto);
  }

  @Delete('devices/:token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unregister a push device (contract §4.12)' })
  async remove(@CurrentUser() u: AuthUser, @Param('token') token: string): Promise<void> {
    await this.svc.removeDevice(u.userId, token);
  }
}
