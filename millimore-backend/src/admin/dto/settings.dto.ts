import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

/** PATCH /admin/settings — every field optional; only sent ones change. */
export class UpdateSettingsDto {
  @ApiPropertyOptional({ example: 0.3, description: "Millimore's share of the trader fee (0..1)." })
  @IsOptional() @IsNumber() @Min(0) @Max(1)
  platformFeeShare?: number;

  @ApiPropertyOptional({ example: 500 })
  @IsOptional() @IsInt() @Min(1) @Max(1000)
  maxLeverage?: number;

  @ApiPropertyOptional({ example: 100 })
  @IsOptional() @IsInt() @Min(1) @Max(1000)
  defaultLeverage?: number;

  @ApiPropertyOptional({ example: 10 })
  @IsOptional() @IsNumber() @Min(0)
  minDeposit?: number;

  @ApiPropertyOptional({ example: 10 })
  @IsOptional() @IsNumber() @Min(0)
  minWithdrawal?: number;

  @ApiPropertyOptional({ example: 25000 })
  @IsOptional() @IsNumber() @Min(0)
  maxWithdrawalPerTx?: number;

  @ApiPropertyOptional({ example: 50000 })
  @IsOptional() @IsNumber() @Min(0)
  maxWithdrawalPerDay?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional() @IsBoolean()
  depositAutoConfirm?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional() @IsBoolean()
  kycRequiredForWithdrawal?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional() @IsBoolean()
  cryptoEnabled?: boolean;

  @ApiPropertyOptional({ example: false })
  @IsOptional() @IsBoolean()
  cardEnabled?: boolean;

  @ApiPropertyOptional({ example: false })
  @IsOptional() @IsBoolean()
  bankEnabled?: boolean;

  @ApiPropertyOptional({ example: false })
  @IsOptional() @IsBoolean()
  maintenanceMode?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional() @IsBoolean()
  referralEnabled?: boolean;

  @ApiPropertyOptional({ example: 0.1, description: "Referrer share of Millimore's fee (0..1)." })
  @IsOptional() @IsNumber() @Min(0) @Max(1)
  referralRevenueShare?: number;

  @ApiPropertyOptional({ example: 0, description: 'One-time bonus on a referral’s first deposit.' })
  @IsOptional() @IsNumber() @Min(0)
  referralSignupBonus?: number;
}

/** Body for flag / KYC decision / reject actions. */
export class ReasonDto {
  @ApiPropertyOptional({ example: 'Suspicious pattern' })
  @IsOptional()
  reason?: string;
}
