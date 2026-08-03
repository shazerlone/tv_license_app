import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsOptional, IsString } from 'class-validator';
import { Role, CreatorStatus } from '@prisma/client';
import { UserDto } from '../../users/dto/user.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

/**
 * Admin view of a user: contract §3 `User` plus `banned` (admin-only field,
 * not consumed by the app). Documented in docs/BACKEND_CONTRACT.md §6.
 */
export class AdminUserDto extends UserDto {
  @ApiProperty({ example: false }) banned: boolean;
  @ApiProperty({ example: false }) frozen: boolean;
  @ApiPropertyOptional({ nullable: true }) adminNote?: string | null;
}

/** GET /admin/users/{id} — the "user 360" detail view. */
export class AdminUserDetailDto {
  @ApiProperty({ type: AdminUserDto }) user: AdminUserDto;
  @ApiProperty({ example: { balance: 1250.5, currency: 'USD' } })
  wallet: { balance: number; currency: string };
  @ApiProperty({
    example: {
      deposits: 3, depositsTotal: 3000, withdrawals: 1, withdrawalsTotal: 500,
      activeCopies: 2, lifetimeCommission: 240.5, payoutMethods: 1,
    },
  })
  stats: {
    deposits: number; depositsTotal: number; withdrawals: number; withdrawalsTotal: number;
    activeCopies: number; lifetimeCommission: number; payoutMethods: number;
  };
  @ApiProperty({ type: [Object], description: 'Recent ledger movements.' })
  ledger: unknown[];
}

/** POST /admin/users/{id}/adjust — manual balance credit/debit. */
export class AdjustBalanceDto {
  @ApiProperty({ example: 100, description: 'Positive credits, negative debits.' })
  amount: number;
  @ApiProperty({ example: 'Goodwill credit for support ticket #123' })
  @IsString()
  reason: string;
}

export class AdminUserPageDto {
  @ApiProperty({ type: [AdminUserDto] }) items: AdminUserDto[];
  @ApiPropertyOptional({ nullable: true }) nextCursor: string | null;
}

/** GET /admin/users query (contract §6). */
export class AdminUsersQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Search name / username / email.' })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;
}

/** PATCH /admin/users/{id} body (contract §6). */
export class UpdateAdminUserDto {
  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  banned?: boolean;

  @ApiPropertyOptional({ enum: CreatorStatus })
  @IsOptional()
  @IsEnum(CreatorStatus)
  creatorStatus?: CreatorStatus;

  @ApiPropertyOptional({ description: 'Freeze: allow login but block withdrawals + new copies.' })
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  frozen?: boolean;

  @ApiPropertyOptional({ description: 'Internal ops note (admin-only).' })
  @IsOptional()
  @IsString()
  adminNote?: string;
}
