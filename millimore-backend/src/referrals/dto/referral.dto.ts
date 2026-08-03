import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength } from 'class-validator';

export class ReferralStatsDto {
  @ApiProperty({ example: 12 }) referred: number;
  @ApiProperty({ example: 7, description: 'Referred users who have deposited.' }) activeReferred: number;
  @ApiProperty({ example: 340.5 }) totalEarned: number;
  @ApiProperty({ example: 90.25 }) earned30d: number;
}

/** GET /referrals/me. */
export class ReferralMeDto {
  @ApiProperty({ example: 'A1B2C3D' }) code: string;
  @ApiProperty({ example: 'https://millimore.app/r/A1B2C3D' }) link: string;
  @ApiProperty({ example: true }) enabled: boolean;
  @ApiProperty({ example: 10, description: 'Referrer share of Millimore fee (%).' }) revenueSharePercent: number;
  @ApiProperty({ example: 0, description: 'One-time bonus on a referral’s first deposit.' }) signupBonus: number;
  @ApiProperty({ type: ReferralStatsDto }) stats: ReferralStatsDto;
}

export class ReferredUserDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() username: string;
  @ApiProperty({ nullable: true }) photoUrl: string | null;
  @ApiProperty() kycVerified: boolean;
  @ApiProperty() hasDeposited: boolean;
  @ApiProperty() joinedAt: string;
  @ApiProperty({ example: 42.5 }) earned: number;
}

/** POST /referrals/apply. */
export class ApplyReferralDto {
  @ApiProperty({ example: 'A1B2C3D' })
  @IsString()
  @MaxLength(16)
  code: string;
}
