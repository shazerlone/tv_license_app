import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsNumber, IsOptional, IsPositive, IsString, MaxLength } from 'class-validator';

/** Contract §alerts — a user's price alert. */
export class PriceAlertDto {
  @ApiProperty({ example: 'pa_1' }) id: string;
  @ApiProperty({ example: 'XAU/USD' }) symbol: string;
  @ApiProperty({ enum: ['above', 'below'] }) direction: string;
  @ApiProperty({ example: 2450 }) targetPrice: number;
  @ApiPropertyOptional({ nullable: true, example: 'Take profit zone' }) note: string | null;
  @ApiProperty({ example: false, description: 'Also email when it triggers.' }) notifyEmail: boolean;
  @ApiProperty({ enum: ['active', 'triggered', 'cancelled'] }) status: string;
  @ApiPropertyOptional({ nullable: true }) triggeredAt: string | null;
  @ApiPropertyOptional({ nullable: true, example: 2450.2 }) triggeredPrice: number | null;
  @ApiProperty() createdAt: string;
}

/** POST /alerts body. */
export class CreatePriceAlertDto {
  @ApiProperty({ example: 'XAU/USD', description: 'A tradable symbol (see GET /symbols).' })
  @IsString()
  symbol: string;

  @ApiProperty({ enum: ['above', 'below'], description: 'Fire when price crosses the target upward (above) or downward (below).' })
  @IsIn(['above', 'below'])
  direction: string;

  @ApiProperty({ example: 2450, description: 'Target price; must be positive.' })
  @IsNumber()
  @IsPositive()
  targetPrice: number;

  @ApiPropertyOptional({ example: 'Take profit zone', maxLength: 140 })
  @IsOptional()
  @IsString()
  @MaxLength(140)
  note?: string;

  @ApiPropertyOptional({ example: false, default: false, description: 'Also send an email when it triggers.' })
  @IsOptional()
  @IsBoolean()
  notifyEmail?: boolean;
}
