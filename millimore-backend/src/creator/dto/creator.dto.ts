import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsString, ValidateNested } from 'class-validator';
import { VerificationDto } from '../../auth/dto/register.dto';

/** GET /creator/status response (contract §4.2). */
export class CreatorStatusDto {
  @ApiProperty({ enum: ['none', 'pending', 'approved', 'rejected', 'suspended'] })
  creatorStatus: string;

  @ApiPropertyOptional({ nullable: true, description: 'Present when rejected/suspended.' })
  reason?: string | null;
}

/** GET /creator/stats — creator dashboard card (contract §5b). */
export class CreatorStatsDto {
  @ApiProperty({ example: 1284 }) followers: number;
  @ApiProperty({ example: 42 }) copiers: number;
  @ApiProperty({ example: 21000 }) aum: number;
  @ApiProperty({ example: 18.45 }) return30d: number;
  @ApiProperty({ example: 0, description: 'Populated with real payouts in milestone 6.' })
  earnings: number;
}

/** POST /creator/apply body (contract §4.2). */
export class ApplyCreatorDto {
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
