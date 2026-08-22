import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

/** Query params for cursor pagination (contract §1). */
export class PaginationQueryDto {
  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @ApiPropertyOptional({ description: 'Opaque cursor from a previous page.' })
  @IsOptional()
  @IsString()
  cursor?: string;
}

/** Envelope for paginated responses: `{ items, nextCursor }` (contract §1). */
export interface Paginated<T> {
  items: T[];
  nextCursor: string | null;
}

/** Encode/decode an opaque cursor around a record id. */
export const encodeCursor = (id: string): string =>
  Buffer.from(id, 'utf8').toString('base64url');

export const decodeCursor = (cursor?: string): string | undefined =>
  cursor ? Buffer.from(cursor, 'base64url').toString('utf8') : undefined;
