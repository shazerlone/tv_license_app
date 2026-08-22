import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

/** Response shape — sensitive details are never returned, only a masked hint. */
export class PayoutMethodDto {
  @ApiProperty({ example: 'pm_ab12cd34' }) id: string;
  @ApiProperty({ enum: ['crypto', 'bank'] }) type: string;
  @ApiProperty({ example: 'My USDT wallet' }) label: string;
  @ApiProperty({ example: 'USDT ••••a1b2' }) masked: string;
  @ApiProperty({ example: '2026-08-02T12:00:00.000Z' }) createdAt: string;
}

/** POST /wallet/payout-methods — sensitive fields are write-only + encrypted. */
export class CreatePayoutMethodDto {
  @ApiProperty({ enum: ['crypto', 'bank'] })
  @IsIn(['crypto', 'bank'])
  type: 'crypto' | 'bank';

  @ApiProperty({ example: 'My USDT wallet' })
  @IsString()
  @MaxLength(60)
  label: string;

  // crypto
  @ApiPropertyOptional({ example: 'USDT' })
  @IsOptional() @IsString() @MaxLength(12)
  asset?: string;

  @ApiPropertyOptional({ example: 'TXyz…addr' })
  @IsOptional() @IsString() @MaxLength(120)
  address?: string;

  // bank
  @ApiPropertyOptional({ example: 'Emirates NBD' })
  @IsOptional() @IsString() @MaxLength(80)
  bankName?: string;

  @ApiPropertyOptional({ example: '00012345678' })
  @IsOptional() @IsString() @MaxLength(40)
  accountNumber?: string;

  @ApiPropertyOptional({ example: 'AE070331234567890123456' })
  @IsOptional() @IsString() @MaxLength(40)
  iban?: string;
}
