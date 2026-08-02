import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsPositive, IsString, MaxLength } from 'class-validator';

/** A deposit method surfaced to the app (crypto live; others "coming soon"). */
export class DepositMethodDto {
  @ApiProperty({ example: 'crypto' }) id: string;
  @ApiProperty({ example: 'Crypto (USDT / BTC)' }) label: string;
  @ApiProperty({ example: true }) active: boolean;
  @ApiPropertyOptional({ example: false }) comingSoon?: boolean;
  @ApiPropertyOptional({ type: [String], example: ['USDT', 'BTC', 'ETH'] })
  assets?: string[];
}

export class DepositDto {
  @ApiProperty({ example: 'dep_ab12cd34' }) id: string;
  @ApiProperty({ example: 250 }) amount: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ example: 'crypto' }) method: string;
  @ApiPropertyOptional({ nullable: true, example: 'USDT' }) asset?: string | null;
  @ApiPropertyOptional({ nullable: true, example: 'TXyz…addr' }) address?: string | null;
  @ApiProperty({ enum: ['pending', 'confirmed', 'failed'] }) status: string;
  @ApiProperty({ example: '2026-08-02T12:00:00.000Z' }) createdAt: string;
  @ApiPropertyOptional({ nullable: true }) confirmedAt?: string | null;
}

/** POST /deposits body — crypto only for now. */
export class CreateDepositDto {
  @ApiProperty({ example: 250, description: 'Amount to deposit in USD terms.' })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiPropertyOptional({ example: 'crypto', description: 'Only "crypto" is active now.' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  method?: string;

  @ApiPropertyOptional({ example: 'USDT' })
  @IsOptional()
  @IsString()
  @MaxLength(12)
  asset?: string;
}
