import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

/** A single message in a pair's public chat (contract §pairs). */
export class PairChatMessageDto {
  @ApiProperty({ example: 'marcus', description: 'Sender handle (username, falling back to name).' })
  author: string;

  @ApiProperty({ example: 'XAU looks heavy into the London close.' })
  text: string;

  @ApiProperty({ example: '2026-08-14T09:30:00.000Z' })
  createdAt: string;
}

/** POST /pairs/{symbol}/chat body. */
export class SendPairChatDto {
  @ApiProperty({ example: 'XAU looks heavy into the London close.', maxLength: 500 })
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  text: string;
}
