import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

/** Contract §3 CopyConfig. */
export class CopyConfigDto {
  @ApiProperty({ example: 't_1' }) traderId: string;
  @ApiProperty({ example: 'acc_1' }) accountId: string;
  @ApiProperty({ example: 500, description: 'Margin allocated from the wallet.' }) amount: number;
  @ApiProperty({ example: 100, description: 'Leverage; exposure = amount × leverage.' }) leverage: number;
  @ApiProperty({ example: 1.0 }) risk: number;
  @ApiProperty({ example: true }) autoCopy: boolean;
  @ApiProperty() startedAt: string;
}

/** POST /copy/{traderId}/start body (contract §4.7). */
export class StartCopyDto {
  @ApiPropertyOptional({
    example: 'acc_1',
    description: 'Optional broker account hint. Funding comes from the wallet.',
  })
  @IsOptional()
  @IsString()
  accountId?: string;

  @ApiProperty({ example: 500, description: 'Margin to allocate from the wallet.' })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiPropertyOptional({ example: 100, description: 'Leverage (1..maxLeverage). Defaults to your setting.' })
  @IsOptional()
  @IsNumber()
  @Min(1)
  leverage?: number;

  @ApiPropertyOptional({ example: 1.0, default: 1.0 })
  @IsOptional()
  @IsNumber()
  @Min(0.1)
  risk?: number;

  @ApiPropertyOptional({ example: true, default: true })
  @IsOptional()
  @IsBoolean()
  autoCopy?: boolean;
}

/** POST /copy/trade/{postId} body — copy a single posted trade. */
export class CopyTradeDto {
  @ApiProperty({ example: 200, description: 'Margin to allocate from the wallet.' })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiPropertyOptional({ example: 100, description: 'Leverage (1..maxLeverage). Defaults to your setting.' })
  @IsOptional()
  @IsNumber()
  @Min(1)
  leverage?: number;
}

/** Contract §3 CopyPosition. */
export class CopyPositionDto {
  @ApiProperty({ example: 'pos_1' }) id: string;
  @ApiProperty({ example: 't_1' }) traderId: string;
  @ApiProperty({ example: 'Marcus' }) traderName: string;
  @ApiProperty({ example: 'EUR/USD' }) pair: string;
  @ApiProperty() isBuy: boolean;
  @ApiProperty({ enum: ['active', 'closed'] }) status: string;
  @ApiProperty({ example: 1.0876 }) entryPrice: number;
  @ApiPropertyOptional({ nullable: true }) exitPrice: number | null;
  @ApiProperty({ example: 12.4 }) pnlAmount: number;
  @ApiProperty({ example: 0.47 }) pnlPercent: number;
  @ApiProperty({ example: 0.1 }) lots: number;
  @ApiProperty() openedAt: string;
  @ApiPropertyOptional({ nullable: true }) closedAt: string | null;
  @ApiProperty({ example: 'acc_1' }) accountId: string;
}

/** GET /portfolio/summary (contract §4.7) — includes the margin view. */
export class PortfolioSummaryDto {
  @ApiProperty() netPnl: number;
  @ApiProperty() openPnl: number;
  @ApiProperty() bookedProfit: number;
  @ApiProperty() bookedLoss: number;
  @ApiProperty() copyingCount: number;
  @ApiProperty() activeCount: number;
  @ApiProperty() closedCount: number;
  @ApiProperty({ description: 'Margin currently allocated to open copies.' }) invested: number;
  @ApiProperty({ example: 1200, description: 'Free margin = spendable wallet balance.' }) freeMargin: number;
  @ApiProperty({ example: 500, description: 'Used margin = sum of active allocations.' }) usedMargin: number;
  @ApiProperty({ example: 1712.4, description: 'Equity = free + used margin + open P/L.' }) equity: number;
  @ApiProperty({ nullable: true, example: 342.5, description: 'Margin level % (equity/used×100); null if no used margin.' }) marginLevel: number | null;
}
