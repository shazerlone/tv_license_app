import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUrl, Max, MaxLength, Min } from 'class-validator';

/** PATCH /me body (contract §4.1: `{ name?, photoUrl?, ... }`). */
export class UpdateMeDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ require_tld: false })
  photoUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(60)
  username?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  market?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  platform?: string;

  // Profile / billing address (contract §12).
  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(160)
  addressLine?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(80)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(20)
  postalCode?: string;

  @ApiPropertyOptional({ example: 100, description: 'Default leverage (1..maxLeverage).' })
  @IsOptional() @IsInt() @Min(1) @Max(500)
  leverage?: number;
}
