import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { TradersService } from './traders.service';
import {
  TraderDto,
  TraderPageDto,
  TradersQueryDto,
  PublicTradeDto,
  EquityPointDto,
} from './dto/trader.dto';

@ApiTags('traders')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('traders')
export class TradersController {
  constructor(private readonly traders: TradersService) {}

  @Get()
  @ApiOperation({ summary: 'Discover traders — filter/sort/paginate (contract §4.4)' })
  @ApiOkResponse({ type: TraderPageDto })
  list(@Query() q: TradersQueryDto): Promise<TraderPageDto> {
    return this.traders.list(q);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a trader (contract §4.4)' })
  @ApiOkResponse({ type: TraderDto })
  getOne(@Param('id') id: string): Promise<TraderDto> {
    return this.traders.getOne(id);
  }

  @Get(':id/trades')
  @ApiOperation({ summary: 'Public trades of a trader (contract §4.4)' })
  @ApiQuery({ name: 'status', required: false, enum: ['active', 'closed'] })
  @ApiOkResponse({ type: [PublicTradeDto] })
  trades(
    @Param('id') id: string,
    @Query('status') status?: 'active' | 'closed',
  ): Promise<PublicTradeDto[]> {
    return this.traders.trades(id, status);
  }

  @Get(':id/equity')
  @ApiOperation({ summary: 'Equity curve of a trader (contract §4.4)' })
  @ApiQuery({ name: 'range', required: false, example: '30d' })
  @ApiOkResponse({ type: [EquityPointDto] })
  equity(@Param('id') id: string, @Query('range') range?: string): Promise<EquityPointDto[]> {
    return this.traders.equity(id, range ?? '30d');
  }
}
