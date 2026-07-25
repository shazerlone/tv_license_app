import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

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
}
