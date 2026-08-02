import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsString, Max, Min, ValidateNested } from 'class-validator';
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

/** GET /creator/earnings (contract §5b) — real wallet-backed earnings. */
export class CreatorEarningsDto {
  @ApiProperty({ example: 320.5, description: 'Withdrawable wallet balance.' })
  balance: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ example: 50, description: 'In open withdrawal requests.' })
  pending: number;
  @ApiProperty({ example: 1240.75, description: 'Lifetime commission earned.' })
  lifetimeEarned: number;
  @ApiProperty({ type: [Object], example: [], description: 'Recent withdrawals.' })
  history: unknown[];
}

/** PATCH /creator/commission body — the trader's performance fee (1–30%). */
export class SetCommissionDto {
  @ApiProperty({ example: 20, minimum: 1, maximum: 30 })
  @IsInt()
  @Min(1)
  @Max(30)
  percent: number;
}

/** PATCH /creator/commission response. */
export class CommissionDto {
  @ApiProperty({ example: 20 }) commissionPercent: number;
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
