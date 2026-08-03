import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsISO8601, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export const AUDIENCES = ['all', 'followers', 'creators'] as const;

/** An announcement as the app sees it (bell feed). */
export class AnnouncementItemDto {
  @ApiProperty() id: string;
  @ApiProperty() title: string;
  @ApiProperty() body: string;
  @ApiProperty() requiredRead: boolean;
  @ApiProperty() createdAt: string;
  @ApiProperty({ description: 'Whether the current user has read/ack’d it.' }) read: boolean;
}

export class AnnouncementFeedDto {
  @ApiProperty({ type: [AnnouncementItemDto] }) items: AnnouncementItemDto[];
  @ApiProperty({ example: 2 }) unread: number;
}

export class CreateAnnouncementDto {
  @ApiProperty({ example: 'Scheduled maintenance Sunday 02:00 UTC' })
  @IsString() @MinLength(3) @MaxLength(160)
  title: string;

  @ApiProperty({ example: 'The app will be briefly unavailable while we upgrade…' })
  @IsString() @MinLength(1) @MaxLength(4000)
  body: string;

  @ApiPropertyOptional({ enum: AUDIENCES })
  @IsOptional() @IsIn(AUDIENCES as unknown as string[])
  audience?: string;

  @ApiPropertyOptional() @IsOptional() @IsBoolean() requiredRead?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() active?: boolean;
  @ApiPropertyOptional({ example: '2026-08-10T00:00:00Z' }) @IsOptional() @IsISO8601() startsAt?: string;
  @ApiPropertyOptional({ example: '2026-08-12T00:00:00Z' }) @IsOptional() @IsISO8601() endsAt?: string;
}

export class UpdateAnnouncementDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(160) title?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) body?: string;
  @ApiPropertyOptional({ enum: AUDIENCES }) @IsOptional() @IsIn(AUDIENCES as unknown as string[]) audience?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() requiredRead?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() active?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() startsAt?: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() endsAt?: string;
}
