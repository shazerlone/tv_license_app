import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

/** POST /stories body. */
export class CreateStoryDto {
  @ApiProperty({ description: 'Hosted media URL (use POST /uploads first).' })
  @IsUrl({ require_tld: false })
  mediaUrl: string;

  @ApiPropertyOptional({ enum: ['image', 'video'], default: 'image' })
  @IsOptional()
  @IsIn(['image', 'video'])
  mediaType?: 'image' | 'video';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(280)
  caption?: string;

  @ApiPropertyOptional({ enum: ['normal', 'recap'], default: 'normal', description: 'recap = live broadcast stat card.' })
  @IsOptional()
  @IsIn(['normal', 'recap'])
  kind?: 'normal' | 'recap';

  @ApiPropertyOptional({ description: 'Required when kind=recap: the broadcast this recap is for (must be yours).' })
  @IsOptional()
  @IsString()
  broadcastId?: string;
}

export class StoryDto {
  @ApiProperty() id: string;
  @ApiProperty() userId: string;
  @ApiProperty() mediaUrl: string;
  @ApiProperty({ enum: ['image', 'video'] }) mediaType: string;
  @ApiPropertyOptional({ nullable: true }) caption: string | null;
  @ApiProperty({ enum: ['normal', 'recap'] }) kind: string;
  @ApiPropertyOptional({ nullable: true }) broadcastId: string | null;
  @ApiProperty({ description: 'Whether the requesting user has viewed it.' }) viewed: boolean;
  @ApiProperty() createdAt: string;
  @ApiProperty() expiresAt: string;
}

class StoryAuthorDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() username: string;
  @ApiPropertyOptional({ nullable: true }) photoUrl: string | null;
}

/** GET /stories item: one author's active stories. */
export class StoryGroupDto {
  @ApiProperty({ type: StoryAuthorDto }) user: StoryAuthorDto;
  @ApiProperty({ type: [StoryDto] }) stories: StoryDto[];
  @ApiProperty({ description: 'True if any story in the group is unseen.' }) hasUnseen: boolean;
}
