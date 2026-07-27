import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { BroadcastsService } from './broadcasts.service';
import {
  BroadcastDto,
  CreateBroadcastDto,
  LiveChatMessageDto,
  SendChatDto,
  ReactDto,
  BroadcastSummaryDto,
} from './dto/broadcast.dto';

@ApiTags('broadcasts')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('broadcasts')
export class BroadcastsController {
  constructor(private readonly broadcasts: BroadcastsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a broadcast (ingest+key+hls) (contract §4.9)' })
  @ApiCreatedResponse({ type: BroadcastDto })
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateBroadcastDto): Promise<BroadcastDto> {
    return this.broadcasts.create(u.userId, dto);
  }

  @Get('live')
  @ApiOperation({ summary: "Who's live now (contract §4.9)" })
  @ApiOkResponse({ type: [BroadcastDto] })
  liveNow(): Promise<BroadcastDto[]> {
    return this.broadcasts.live();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a broadcast (contract §4.9)' })
  @ApiOkResponse({ type: BroadcastDto })
  get(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<BroadcastDto> {
    return this.broadcasts.get(id, u.userId);
  }

  @Post(':id/start')
  @ApiOperation({ summary: 'Go live; notifies followers (contract §4.9)' })
  @ApiOkResponse({ type: BroadcastDto })
  start(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<BroadcastDto> {
    return this.broadcasts.start(u.userId, id);
  }

  @Post(':id/end')
  @ApiOperation({ summary: 'End the broadcast; returns a summary (contract §4.9)' })
  @ApiOkResponse({ type: BroadcastSummaryDto })
  end(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<BroadcastSummaryDto> {
    return this.broadcasts.end(u.userId, id);
  }

  @Post(':id/destinations/youtube/connect')
  @ApiOperation({ summary: 'Begin YouTube simulcast OAuth (contract §4.9)' })
  connectYoutube(@CurrentUser() u: AuthUser, @Param('id') id: string): Promise<{ authUrl: string }> {
    return this.broadcasts.connectYoutube(u.userId, id);
  }

  @Post(':id/destinations/:platform/disconnect')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Disconnect a simulcast destination (contract §4.9)' })
  async disconnect(
    @CurrentUser() u: AuthUser,
    @Param('id') id: string,
    @Param('platform') platform: string,
  ): Promise<void> {
    await this.broadcasts.disconnectDestination(u.userId, id, platform);
  }

  @Get(':id/chat')
  @ApiOperation({ summary: 'Recent live chat (contract §4.11)' })
  @ApiOkResponse({ type: [LiveChatMessageDto] })
  chat(@Param('id') id: string): Promise<LiveChatMessageDto[]> {
    return this.broadcasts.chat(id);
  }

  @Post(':id/chat')
  @ApiOperation({ summary: 'Send a chat message; pushed over WS (contract §4.11)' })
  @ApiCreatedResponse({ type: LiveChatMessageDto })
  sendChat(
    @CurrentUser() u: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendChatDto,
  ): Promise<LiveChatMessageDto> {
    return this.broadcasts.sendChat(u.userId, id, dto.text);
  }

  @Post(':id/react')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Send a heart reaction; pushed over WS (contract §5)' })
  async react(@Param('id') id: string, @Body() dto: ReactDto): Promise<void> {
    await this.broadcasts.react(id, dto.count ?? 1);
  }
}
