import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

/** Contract §3 CopyConfig. */
export class CopyConfigDto {
  @ApiProperty({ example: 't_1' }) traderId: string;
  @ApiProperty({ example: 'acc_1' }) accountId: string;
  @ApiProperty({ example: 500 }) amount: number;
  @ApiProperty({ example: 1.0 }) risk: number;
  @ApiProperty({ example: true }) autoCopy: boolean;
  @ApiProperty() startedAt: string;
}

/** POST /copy/{traderId}/start body (contract §4.7). */
export class StartCopyDto {
  @ApiProperty({ example: 'acc_1' })
  @IsString()
  accountId: string;

  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;

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

/** GET /portfolio/summary (contract §4.7). */
export class PortfolioSummaryDto {
  @ApiProperty() netPnl: number;
  @ApiProperty() openPnl: number;
  @ApiProperty() bookedProfit: number;
  @ApiProperty() bookedLoss: number;
  @ApiProperty() copyingCount: number;
  @ApiProperty() activeCount: number;
  @ApiProperty() closedCount: number;
  @ApiProperty() invested: number;
}
