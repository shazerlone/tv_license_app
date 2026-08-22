import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { SupportService } from './support.service';
import { CreateTicketDto, ReplyTicketDto, TicketDetailDto, TicketDto } from './dto/support.dto';

@ApiTags('support')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('support/tickets')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Get()
  @ApiOperation({ summary: 'My support tickets' })
  @ApiOkResponse({ type: [TicketDto] })
  list(@CurrentUser() user: AuthUser): Promise<TicketDto[]> {
    return this.support.listMine(user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Open a support ticket' })
  @ApiOkResponse({ type: TicketDto })
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTicketDto): Promise<TicketDto> {
    return this.support.create(user.userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ticket thread (public messages only)' })
  @ApiOkResponse({ type: TicketDetailDto })
  get(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<TicketDetailDto> {
    return this.support.getMine(user.userId, id);
  }

  @Post(':id/messages')
  @ApiOperation({ summary: 'Reply to my ticket' })
  @ApiOkResponse({ type: TicketDetailDto })
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReplyTicketDto,
  ): Promise<TicketDetailDto> {
    return this.support.reply(user.userId, id, dto.body);
  }
}
