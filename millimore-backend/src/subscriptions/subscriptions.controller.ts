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
import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { SubscriptionsService } from './subscriptions.service';
import { TraderDto } from '../traders/dto/trader.dto';

class NotifyDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  on: boolean;
}

@ApiTags('subscriptions')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Get()
  @ApiOperation({ summary: 'Traders I subscribe to (contract §4.5)' })
  @ApiOkResponse({ type: [TraderDto] })
  list(@CurrentUser() u: AuthUser): Promise<TraderDto[]> {
    return this.subs.list(u.userId);
  }

  @Post(':traderId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Subscribe to a trader (contract §4.5)' })
  async subscribe(@CurrentUser() u: AuthUser, @Param('traderId') traderId: string): Promise<void> {
    await this.subs.subscribe(u.userId, traderId);
  }

  @Delete(':traderId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unsubscribe from a trader (contract §4.5)' })
  async unsubscribe(
    @CurrentUser() u: AuthUser,
    @Param('traderId') traderId: string,
  ): Promise<void> {
    await this.subs.unsubscribe(u.userId, traderId);
  }

  @Post(':traderId/notify')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Toggle the notification bell (contract §4.5)' })
  async notify(
    @CurrentUser() u: AuthUser,
    @Param('traderId') traderId: string,
    @Body() dto: NotifyDto,
  ): Promise<void> {
    await this.subs.setNotify(u.userId, traderId, dto.on);
  }
}
