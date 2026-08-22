import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

/** Contract §3 `Trader` (public profile card). */
export class TraderDto {
  @ApiProperty({ example: 't_1' }) id: string;
  @ApiProperty({ example: 'Marcus Sterling' }) name: string;
  @ApiProperty({ example: 'marcussterling' }) username: string;
  @ApiPropertyOptional({ nullable: true }) photoUrl: string | null;
  @ApiProperty() isVerified: boolean;
  @ApiProperty() isLive: boolean;
  @ApiProperty({ example: 18.45 }) returnPercent: number;
  @ApiProperty({ example: 30 }) returnDays: number;
  @ApiProperty({ example: 12400 }) followers: number;
  @ApiProperty({ example: 1840 }) copiers: number;
  @ApiProperty({ example: 2300000 }) aum: number;
  @ApiProperty({ example: 72 }) winRate: number;
  @ApiProperty({ example: 9.2 }) maxDrawdown: number;
  @ApiProperty({ example: 612 }) totalTrades: number;
  @ApiProperty({ example: 20, description: 'Performance fee % charged to copiers (1–30).' })
  commissionPercent: number;
  @ApiProperty({ example: 'Forex' }) category: string;
  @ApiProperty({ type: [String], example: ['Price Action', 'EUR/USD'] }) tags: string[];
  @ApiPropertyOptional({ nullable: true }) bio: string | null;
}

export class TraderPageDto {
  @ApiProperty({ type: [TraderDto] }) items: TraderDto[];
  @ApiPropertyOptional({ nullable: true }) nextCursor: string | null;
}

/** GET /traders query (contract §4.4). */
export class TradersQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ example: 'Forex' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ description: 'Search name / username.' })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({ enum: ['copiers', 'return'] })
  @IsOptional()
  @IsIn(['copiers', 'return'])
  sort?: 'copiers' | 'return';
}

/** Public trade (CopyPosition-like, contract §4.4 GET /traders/{id}/trades). */
export class PublicTradeDto {
  @ApiProperty({ example: 'ptr_1' }) id: string;
  @ApiProperty({ example: 't_1' }) traderId: string;
  @ApiProperty({ example: 'Marcus Sterling' }) traderName: string;
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
}

/** Equity curve point (contract §4.4 GET /traders/{id}/equity). */
export class EquityPointDto {
  @ApiProperty({ example: '2026-06-26T00:00:00Z' }) t: string;
  @ApiProperty({ example: 10240.5 }) value: number;
}

/** Reel (contract §4.4 GET /discover/reels). */
export class ReelDto {
  @ApiProperty({ enum: ['live', 'trade', 'lesson'] }) kind: string;
  @ApiProperty({ type: TraderDto }) trader: TraderDto;
  @ApiPropertyOptional({ nullable: true }) post?: unknown;
  @ApiPropertyOptional({ nullable: true }) title?: string | null;
  @ApiPropertyOptional({ type: [String] }) points?: string[];
  @ApiPropertyOptional({ nullable: true }) viewers?: number | null;
}
