import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
} from 'class-validator';

export const PAYOUT_STATUSES = ['pending', 'approved', 'rejected', 'paid'] as const;

/** A payout row (contract §5b/§6). Money movement only; earnings are computed. */
export class PayoutDto {
  @ApiProperty({ example: 'po_ab12cd34' }) id: string;
  @ApiProperty({ example: 'u_123' }) userId: string;
  @ApiProperty({ example: 250.5 }) amount: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ enum: PAYOUT_STATUSES }) status: string;
  @ApiPropertyOptional({ nullable: true, example: 'bank' }) method?: string | null;
  @ApiPropertyOptional({ nullable: true }) note?: string | null;
  @ApiPropertyOptional({ nullable: true }) reason?: string | null;
  @ApiProperty({ example: '2026-08-02T12:00:00.000Z' }) createdAt: string;
  @ApiPropertyOptional({ nullable: true }) decidedAt?: string | null;
}

/** Admin payout row includes who is requesting. */
export class AdminPayoutDto extends PayoutDto {
  @ApiProperty({ example: { id: 'u_123', name: 'Marcus', username: 'marcus' } })
  requester: { id: string; name: string; username: string; email?: string | null };
}

/** POST /creator/payouts body. */
export class RequestPayoutDto {
  @ApiProperty({ example: 250.5, description: 'Amount to withdraw, ≤ available balance.' })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiProperty({ example: 'pm_ab12cd34', description: 'Saved payout method id to send to.' })
  @IsString()
  @MaxLength(40)
  methodId: string;

  @ApiPropertyOptional({ example: 'bank' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  method?: string;

  @ApiPropertyOptional({ example: 'Monthly withdrawal' })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}

/** Admin decision body for reject (reason required) / approve (optional note). */
export class PayoutDecisionDto {
  @ApiPropertyOptional({ example: 'Verified, sent via bank transfer.' })
  @IsOptional()
  @IsString()
  @MaxLength(280)
  reason?: string;
}

/** GET /admin/payouts query. */
export class AdminPayoutsQueryDto {
  @ApiPropertyOptional({ enum: PAYOUT_STATUSES })
  @IsOptional()
  @IsIn(PAYOUT_STATUSES as unknown as string[])
  status?: string;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional()
  @IsNumber()
  limit?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cursor?: string;
}
