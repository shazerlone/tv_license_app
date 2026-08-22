import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export const TICKET_CATEGORIES = ['general', 'deposit', 'withdrawal', 'kyc', 'trading', 'account'] as const;
export const TICKET_PRIORITIES = ['low', 'normal', 'high', 'urgent'] as const;
export const TICKET_STATUSES = ['open', 'pending', 'resolved', 'closed'] as const;

export class TicketMessageDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: ['user', 'admin'] }) authorRole: string;
  @ApiProperty() body: string;
  @ApiProperty({ description: 'Admin-only internal note (never shown to the user).' }) internal: boolean;
  @ApiProperty() createdAt: string;
}

export class TicketDto {
  @ApiProperty({ example: 'tkt_ab12cd34' }) id: string;
  @ApiProperty() subject: string;
  @ApiProperty({ enum: TICKET_CATEGORIES }) category: string;
  @ApiProperty({ enum: TICKET_PRIORITIES }) priority: string;
  @ApiProperty({ enum: TICKET_STATUSES }) status: string;
  @ApiProperty() createdAt: string;
  @ApiProperty() lastMessageAt: string;
}

export class TicketDetailDto extends TicketDto {
  @ApiProperty({ type: [TicketMessageDto] }) messages: TicketMessageDto[];
}

export class CreateTicketDto {
  @ApiProperty({ example: 'My withdrawal is stuck' })
  @IsString() @MinLength(3) @MaxLength(140)
  subject: string;

  @ApiProperty({ example: 'I requested $200 two days ago…' })
  @IsString() @MinLength(1) @MaxLength(4000)
  message: string;

  @ApiPropertyOptional({ enum: TICKET_CATEGORIES })
  @IsOptional() @IsIn(TICKET_CATEGORIES as unknown as string[])
  category?: string;

  @ApiPropertyOptional({ enum: TICKET_PRIORITIES })
  @IsOptional() @IsIn(TICKET_PRIORITIES as unknown as string[])
  priority?: string;
}

export class ReplyTicketDto {
  @ApiProperty({ example: 'Any update on this?' })
  @IsString() @MinLength(1) @MaxLength(4000)
  body: string;
}

export class AdminReplyDto extends ReplyTicketDto {
  @ApiPropertyOptional({ description: 'true = internal note (not shown to the user).' })
  @IsOptional() @IsBoolean()
  internal?: boolean;
}

export class UpdateTicketDto {
  @ApiPropertyOptional({ enum: TICKET_STATUSES })
  @IsOptional() @IsIn(TICKET_STATUSES as unknown as string[])
  status?: string;

  @ApiPropertyOptional({ enum: TICKET_PRIORITIES })
  @IsOptional() @IsIn(TICKET_PRIORITIES as unknown as string[])
  priority?: string;
}
