import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { CopyService } from './copy.service';
import {
  CopyConfigDto,
  CopyPositionDto,
  StartCopyDto,
  PortfolioSummaryDto,
} from './dto/copy.dto';

@ApiTags('copy')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class CopyController {
  constructor(private readonly copy: CopyService) {}

  @Post('copy/:traderId/start')
  @ApiOperation({ summary: 'Start copying a trader (contract §4.7)' })
  @ApiOkResponse({ type: CopyConfigDto })
  start(
    @CurrentUser() u: AuthUser,
    @Param('traderId') traderId: string,
    @Body() dto: StartCopyDto,
  ): Promise<CopyConfigDto> {
    return this.copy.start(u.userId, traderId, dto);
  }

  @Post('copy/:traderId/stop')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Stop copying a trader; closes open positions (contract §4.7)' })
  async stop(@CurrentUser() u: AuthUser, @Param('traderId') traderId: string): Promise<void> {
    await this.copy.stop(u.userId, traderId);
  }

  @Get('copy')
  @ApiOperation({ summary: 'My active copy configs (contract §4.7)' })
  @ApiOkResponse({ type: [CopyConfigDto] })
  configs(@CurrentUser() u: AuthUser): Promise<CopyConfigDto[]> {
    return this.copy.listConfigs(u.userId);
  }

  @Get('positions')
  @ApiOperation({ summary: 'My copied positions with live P/L (contract §4.7)' })
  @ApiQuery({ name: 'status', required: false, enum: ['active', 'closed'] })
  @ApiOkResponse({ type: [CopyPositionDto] })
  positions(
    @CurrentUser() u: AuthUser,
    @Query('status') status?: 'active' | 'closed',
  ): Promise<CopyPositionDto[]> {
    return this.copy.positions(u.userId, status);
  }

  @Get('portfolio/summary')
  @ApiOperation({ summary: 'Portfolio summary (contract §4.7)' })
  @ApiOkResponse({ type: PortfolioSummaryDto })
  summary(@CurrentUser() u: AuthUser): Promise<PortfolioSummaryDto> {
    return this.copy.portfolioSummary(u.userId);
  }
}
