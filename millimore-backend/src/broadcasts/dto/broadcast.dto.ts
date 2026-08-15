import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';

/** Contract §3 Broadcast. Ingest/streamKey are only included for the owner. */
export class BroadcastDto {
  @ApiProperty({ example: 'b_1' }) id: string;
  @ApiProperty({ example: 'u_1' }) creatorId: string;
  // Trader identity so the app can render live cards without a second lookup.
  @ApiPropertyOptional({ nullable: true, example: 't_1' }) traderId?: string | null;
  @ApiPropertyOptional({ nullable: true, example: 'Marcus Sterling' }) name?: string | null;
  @ApiPropertyOptional({ nullable: true, example: 'marcussterling' }) username?: string | null;
  @ApiPropertyOptional({ nullable: true, example: 'https://…/photo.jpg' }) photoUrl?: string | null;
  @ApiProperty({ example: 'Live trading' }) title: string;
  @ApiProperty({ enum: ['connecting', 'live', 'ended'] }) phase: string;
  @ApiPropertyOptional({ description: 'Owner-only', nullable: true }) ingestUrl?: string | null;
  @ApiPropertyOptional({ description: 'Owner-only', nullable: true }) streamKey?: string | null;
  @ApiProperty() hlsUrl: string;
  @ApiProperty({ example: 42 }) viewers: number;
  @ApiProperty({ example: 80 }) peakViewers: number;
  @ApiPropertyOptional({ nullable: true }) startedAt: string | null;
  @ApiPropertyOptional({ nullable: true }) endedAt: string | null;
  @ApiProperty({ type: [Object], example: [{ id: 'youtube', connected: true }] })
  destinations: unknown[];
}

export class CreateBroadcastDto {
  @ApiProperty({ example: 'Live trading — London session' })
  @IsString()
  @MinLength(1)
  @MaxLength(140)
  title: string;
}

/** Contract §3 LiveChatMessage. */
export class LiveChatMessageDto {
  @ApiProperty({ example: 'alex_t' }) author: string;
  @ApiProperty() text: string;
  @ApiProperty({ enum: ['millimore', 'youtube', 'facebook'] }) source: string;
  @ApiProperty() byHost: boolean;
  @ApiProperty() createdAt: string;
}

export class SendChatDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  text: string;
}

export class ReactDto {
  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  count?: number;
}

/** POST /broadcasts/{id}/end summary. */
export class BroadcastSummaryDto {
  @ApiProperty({ example: 3600, description: 'seconds' }) duration: number;
  @ApiProperty({ example: 80 }) peakViewers: number;
  @ApiProperty({ example: 0 }) trades: number;
  @ApiProperty({ example: 0 }) pnl: number;
}
