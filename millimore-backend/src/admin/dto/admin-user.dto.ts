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
}
