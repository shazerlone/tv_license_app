import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { TraderDto } from '../../traders/dto/trader.dto';

/** Contract §3 `Post`. */
export class PostDto {
  @ApiProperty({ example: 'p_1' }) id: string;
  @ApiProperty({ type: TraderDto }) trader: TraderDto;
  @ApiProperty({ enum: ['analysis', 'trade', 'lesson', 'update'] }) type: string;
  @ApiProperty() content: string;
  @ApiPropertyOptional({ nullable: true }) pair: string | null;
  @ApiPropertyOptional({ nullable: true }) title: string | null;
  @ApiProperty({ type: [String] }) points: string[];
  @ApiProperty({ example: 284 }) likes: number;
  @ApiProperty({ example: 47 }) comments: number;
  @ApiProperty() createdAt: string;
  @ApiProperty() isLiked: boolean;
  @ApiProperty() saved: boolean;
}

/** Contract §3 `Comment`. */
export class CommentDto {
  @ApiProperty({ example: 'c_1' }) id: string;
  @ApiProperty({ example: 'Priya' }) author: string;
  @ApiProperty({ example: 'priyatrades' }) username: string;
  @ApiProperty() text: string;
  @ApiProperty() createdAt: string;
  @ApiProperty() byMe: boolean;
}

/** POST /posts compose body (contract §4.6). */
export class CreatePostDto {
  @ApiProperty({ enum: ['trade', 'analysis', 'lesson', 'update'] })
  @IsIn(['trade', 'analysis', 'lesson', 'update'])
  type: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  pair?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  points?: string[];
}

/** POST /posts/{id}/comments body. */
export class CreateCommentDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  text: string;
}

/** Response of like/unlike (contract §4.5 → { likes }). */
export class LikesDto {
  @ApiProperty({ example: 285 }) likes: number;
}
