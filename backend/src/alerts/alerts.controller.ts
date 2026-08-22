import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiCreatedResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { AlertsService } from './alerts.service';
import { CreatePriceAlertDto, PriceAlertDto } from './dto/alert.dto';

@ApiTags('alerts')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alerts: AlertsService) {}

  @Get()
  @ApiOperation({ summary: 'My price alerts (contract §alerts)' })
  @ApiQuery({ name: 'status', required: false, enum: ['active', 'triggered', 'cancelled'] })
  @ApiOkResponse({ type: [PriceAlertDto] })
  list(@CurrentUser() u: AuthUser, @Query('status') status?: string): Promise<PriceAlertDto[]> {
    return this.alerts.list(u.userId, status);
  }

  @Post()
  @ApiOperation({ summary: 'Create a price alert (contract §alerts)' })
  @ApiCreatedResponse({ type: PriceAlertDto })
  create(@CurrentUser() u: AuthUser, @Body() dto: CreatePriceAlertDto): Promise<PriceAlertDto> {
    return this.alerts.create(u.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Cancel a price alert (contract §alerts)' })
  async cancel(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<void> {
    await this.alerts.cancel(u.userId, id);
  }
}
