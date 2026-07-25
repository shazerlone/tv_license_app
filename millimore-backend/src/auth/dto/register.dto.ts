import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** Creator verification block (contract §4.1 register/creator, §4.2 apply). */
export class VerificationDto {
  @ApiProperty({ example: 'MetaTrader 5' })
  @IsString()
  platform: string;

  @ApiPropertyOptional({ example: 'XM-Live3' })
  @IsOptional()
  @IsString()
  server?: string;

  @ApiPropertyOptional({ example: '50231487' })
  @IsOptional()
  @IsString()
  account?: string;

  /** Write-only: stored encrypted, never returned. */
  @ApiPropertyOptional({ example: 'investor-pw', writeOnly: true })
  @IsOptional()
  @IsString()
  investorPassword?: string;

  @ApiPropertyOptional({ example: 'https://storage/statement.pdf' })
  @IsOptional()
  @IsString()
  statementUrl?: string;
}

/** POST /auth/register/follower */
export class RegisterFollowerDto {
  @ApiProperty({ example: 'Priya Sharma' })
  @IsString()
  @MaxLength(120)
  name: string;

  @ApiProperty({ example: '+91 90000 00000' })
  @IsString()
  phone: string;

  @ApiProperty({ example: 'IN' })
  @IsString()
  @Length(2, 2)
  residenceIso: string;

  @ApiPropertyOptional({ example: 'beginner' })
  @IsOptional()
  @IsString()
  experience?: string;

  @ApiPropertyOptional({ type: [String], example: ['Forex', 'Crypto'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  interests?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  photoUrl?: string;
}

/** POST /auth/register/creator */
export class RegisterCreatorDto {
  @ApiProperty({ example: 'Marcus Sterling' })
  @IsString()
  @MaxLength(120)
  name: string;

  @ApiProperty({ example: '+91 90000 00000' })
  @IsString()
  phone: string;

  @ApiProperty({ example: 'IN' })
  @IsString()
  @Length(2, 2)
  residenceIso: string;

  @ApiProperty({ example: 'Forex' })
  @IsString()
  market: string;

  @ApiProperty({ example: 'MetaTrader 5' })
  @IsString()
  platform: string;

  @ApiProperty({ type: VerificationDto })
  @ValidateNested()
  @Type(() => VerificationDto)
  verification: VerificationDto;
}
