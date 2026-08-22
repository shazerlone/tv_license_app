import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray, IsIn, IsNumber, IsOptional, IsString, IsUrl, MaxLength, MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { TraderDto } from '../../traders/dto/trader.dto';

/** The copyable trade attached to a `type:"trade"` post (contract §4.6). */
export class TradePostDto {
  @ApiProperty({ enum: ['buy', 'sell'] }) side: string;
  @ApiProperty({ enum: ['market', 'limit'] }) entryType: string;
  @ApiPropertyOptional({ nullable: true, example: 2411.3 }) entryPrice: number | null;
  @ApiPropertyOptional({ nullable: true }) sl: number | null;
  @ApiPropertyOptional({ nullable: true }) tp: number | null;
  @ApiPropertyOptional({ nullable: true, example: 1.5 }) slPct: number | null;
  @ApiPropertyOptional({ nullable: true, example: 3.0 }) tpPct: number | null;
}

/** Contract §3 `Post`. */
export class PostDto {
  @ApiProperty({ example: 'p_1' }) id: string;
  @ApiProperty({ type: TraderDto }) trader: TraderDto;
  @ApiProperty({ enum: ['analysis', 'trade', 'lesson', 'update'] }) type: string;
  @ApiProperty() content: string;
  @ApiPropertyOptional({ nullable: true }) pair: string | null;
  @ApiPropertyOptional({ nullable: true }) title: string | null;
  @ApiProperty({ type: [String] }) points: string[];
  @ApiPropertyOptional({ nullable: true, description: 'Chart/setup image.' }) imageUrl: string | null;
  @ApiPropertyOptional({ type: TradePostDto, nullable: true, description: 'Present on trade posts.' })
  trade: TradePostDto | null;
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

/** Nested trade payload the app sends on a `type:"trade"` post. */
export class CreateTradeDto {
  @ApiPropertyOptional({ enum: ['buy', 'sell'] })
  @IsOptional() @IsIn(['buy', 'sell'])
  side?: string;

  @ApiPropertyOptional({ enum: ['market', 'limit'] })
  @IsOptional() @IsIn(['market', 'limit'])
  entryType?: string;

  @ApiPropertyOptional() @IsOptional() @IsNumber() entryPrice?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() sl?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() tp?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() slPct?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() tpPct?: number;
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

  @ApiPropertyOptional({ description: 'Uploaded image URL (from POST /uploads).' })
  @IsOptional()
  @IsString()
  @IsUrl({ require_tld: false })
  imageUrl?: string;

  // Preferred: the app sends the trade as a nested object on a trade post.
  @ApiPropertyOptional({ type: CreateTradeDto, description: 'Trade payload (type=trade) — makes the post copyable.' })
  @IsOptional()
  @ValidateNested()
  @Type(() => CreateTradeDto)
  trade?: CreateTradeDto;

  // Back-compat: the same fields may also arrive flat at the top level.
  @ApiPropertyOptional({ enum: ['buy', 'sell'] })
  @IsOptional() @IsIn(['buy', 'sell'])
  side?: string;

  @ApiPropertyOptional({ enum: ['market', 'limit'] })
  @IsOptional() @IsIn(['market', 'limit'])
  entryType?: string;

  @ApiPropertyOptional() @IsOptional() @IsNumber() entryPrice?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() sl?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() tp?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() slPct?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() tpPct?: number;
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
