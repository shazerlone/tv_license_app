import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export const SIMULCAST_PLATFORMS = ['youtube', 'facebook', 'twitch', 'custom'] as const;

/** A simulcast destination (keys are write-only; only `masked` is returned). */
export class BroadcastOutputDto {
  @ApiProperty({ example: 'out_ab12cd34' }) id: string;
  @ApiProperty({ enum: SIMULCAST_PLATFORMS }) platform: string;
  @ApiProperty({ example: 'rtmp://a.rtmp.youtube.com/live2' }) targetUrl: string;
  @ApiProperty({ example: 'youtube ••••a1b2' }) masked: string;
  @ApiProperty({ example: true }) enabled: boolean;
  @ApiProperty() createdAt: string;
}

/** POST /broadcasts/{id}/outputs — add a simulcast target. */
export class CreateOutputDto {
  @ApiProperty({ enum: SIMULCAST_PLATFORMS })
  @IsIn(SIMULCAST_PLATFORMS as unknown as string[])
  platform: string;

  @ApiProperty({ example: 'live_xxxxxxxx', description: 'The destination stream key (write-only).' })
  @IsString()
  @MaxLength(200)
  streamKey: string;

  @ApiPropertyOptional({ example: 'rtmp://a.rtmp.youtube.com/live2', description: 'RTMP URL; auto-filled for known platforms, required for custom.' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  url?: string;
}

export class ToggleOutputDto {
  @ApiProperty({ example: false })
  @IsBoolean()
  enabled: boolean;
}
