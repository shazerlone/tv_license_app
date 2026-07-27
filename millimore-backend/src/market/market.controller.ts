import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PricesService, PriceMap } from './prices.service';

@ApiTags('market')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller()
export class MarketController {
  constructor(private readonly prices: PricesService) {}

  @Get('symbols')
  @ApiOperation({ summary: 'List tradable symbols (contract §4.8)' })
  @ApiOkResponse({ type: [String] })
  symbols(): string[] {
    return this.prices.symbols();
  }

  @Get('prices')
  @ApiOperation({ summary: 'Price snapshot; realtime comes over WS (contract §4.8)' })
  @ApiQuery({ name: 'symbols', required: false, example: 'XAU/USD,EUR/USD' })
  @ApiOkResponse({ schema: { example: { 'XAU/USD': 2015.3, 'EUR/USD': 1.0851 } } })
  snapshot(@Query('symbols') symbols?: string): PriceMap {
    const only = symbols?.split(',').map((s) => s.trim()).filter(Boolean);
    return this.prices.snapshot(only);
  }
}
