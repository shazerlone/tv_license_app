import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiParam, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PairsService } from './pairs.service';
import { PairChatMessageDto, SendPairChatDto } from './dto/pair-chat.dto';

@ApiTags('pairs')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('pairs')
export class PairsController {
  constructor(private readonly pairs: PairsService) {}

  @Get(':symbol/chat')
  @ApiOperation({ summary: 'Recent messages in a pair’s public chat (contract §pairs)' })
  @ApiParam({ name: 'symbol', example: 'XAU%2FUSD', description: 'URL-encoded symbol, e.g. XAU%2FUSD.' })
  @ApiQuery({ name: 'limit', required: false, example: 100 })
  @ApiOkResponse({ type: [PairChatMessageDto] })
  list(
    @Param('symbol') symbol: string,
    @Query('limit') limit?: string,
  ): Promise<PairChatMessageDto[]> {
    const n = limit ? Number(limit) : undefined;
    return this.pairs.list(symbol, Number.isFinite(n) ? n : undefined);
  }

  @Post(':symbol/chat')
  @ApiOperation({ summary: 'Send a message to a pair’s public chat; fans out over WS pair:{symbol}' })
  @ApiParam({ name: 'symbol', example: 'XAU%2FUSD', description: 'URL-encoded symbol, e.g. XAU%2FUSD.' })
  @ApiOkResponse({ type: PairChatMessageDto })
  send(
    @CurrentUser() u: AuthUser,
    @Param('symbol') symbol: string,
    @Body() dto: SendPairChatDto,
  ): Promise<PairChatMessageDto> {
    return this.pairs.send(u.userId, symbol, dto.text);
  }
}
