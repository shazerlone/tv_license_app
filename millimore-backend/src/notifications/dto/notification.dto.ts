import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayNotEmpty, IsArray, IsIn, IsOptional, IsString } from 'class-validator';

/** Contract §4.12 notification item. */
export class NotificationDto {
  @ApiProperty({ example: 'n_1' }) id: string;
  @ApiProperty({ example: 'creator.status' }) type: string;
  @ApiProperty() title: string;
  @ApiPropertyOptional({ nullable: true }) body: string | null;
  @ApiPropertyOptional({ description: 'Arbitrary payload (traderId, pair, pnl…).' })
  data?: unknown;
  @ApiProperty() createdAt: string;
  @ApiProperty() read: boolean;
}

/** POST /notifications/read body. */
export class MarkReadDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  ids: string[];
}

/** POST /devices body (contract §4.12 — push registration). */
export class RegisterDeviceDto {
  @ApiProperty({ enum: ['android', 'ios'] })
  @IsIn(['android', 'ios'])
  platform: 'android' | 'ios';

  @ApiProperty({ description: 'FCM/APNs device token.' })
  @IsString()
  token: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  appVersion?: string;
}
