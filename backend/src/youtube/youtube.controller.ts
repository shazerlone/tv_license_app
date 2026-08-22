import { Controller, Get, HttpCode, HttpStatus, Post, Query, Res, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiExcludeEndpoint, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { YoutubeService } from './youtube.service';

@ApiTags('youtube')
@Controller('youtube')
export class YoutubeController {
  constructor(private readonly youtube: YoutubeService) {}

  @Get('status')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Is my YouTube account connected?' })
  status(@CurrentUser() u: AuthUser) {
    return this.youtube.status(u.userId);
  }

  @Post('connect')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get the Google consent URL to connect YouTube' })
  connect(@CurrentUser() u: AuthUser) {
    return { url: this.youtube.getAuthUrl(u.userId) };
  }

  @Post('disconnect')
  @ApiBearerAuth('bearer')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Disconnect my YouTube account' })
  disconnect(@CurrentUser() u: AuthUser) {
    return this.youtube.disconnect(u.userId);
  }

  @Get('callback')
  @ApiExcludeEndpoint() // Google redirect target — not a client-facing API
  async callback(@Query('code') code: string, @Query('state') state: string, @Res() res: Response) {
    try {
      await this.youtube.handleCallback(code, state);
      res.status(200).send('<h3>YouTube connected ✅ — you can close this window.</h3>');
    } catch {
      res.status(400).send('<h3>YouTube connection failed. Please try again.</h3>');
    }
  }
}
