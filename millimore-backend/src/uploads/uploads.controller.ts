import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  Res,
  UseGuards,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags, ApiOkResponse } from '@nestjs/swagger';
import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';
import type { Request, Response } from 'express';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { genId } from '../common/ids';

class UploadDto {
  @ApiProperty({ example: 'image/jpeg' })
  @IsString()
  contentType: string;

  @ApiProperty({ description: 'Base64 file data (raw or data-URL).' })
  @IsString()
  data: string;

  @ApiProperty({ required: false, description: 'Optional label, e.g. "statement".' })
  @IsOptional()
  @IsString()
  kind?: string;
}

class UploadResultDto {
  @ApiProperty({ example: 'https://…/v1/uploads/up_123' }) url: string;
  @ApiProperty({ example: 'up_123' }) id: string;
}

/**
 * Media uploads (contract §5b). Replaces the app's base64 photoUrl with a real
 * hosted URL. Dev stores bytes in Postgres (stateless across instances) and
 * serves them; wire STORAGE_* env for S3+CloudFront in production.
 */
@ApiTags('uploads')
@Controller('uploads')
export class UploadsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('bearer')
  @ApiOperation({ summary: 'Upload media, returns a hosted URL (contract §5b)' })
  @ApiOkResponse({ type: UploadResultDto })
  async upload(
    @CurrentUser() user: AuthUser,
    @Body() dto: UploadDto,
    @Req() req: Request,
  ): Promise<UploadResultDto> {
    const base64 = dto.data.includes(',') ? dto.data.split(',')[1] : dto.data;
    let buf: Buffer;
    try {
      buf = Buffer.from(base64, 'base64');
    } catch {
      throw new BadRequestException({ code: 'bad_upload', message: 'Invalid base64 data' });
    }
    if (buf.length === 0) throw new BadRequestException({ code: 'empty_upload', message: 'Empty file' });
    if (buf.length > 8 * 1024 * 1024) {
      throw new BadRequestException({ code: 'too_large', message: 'Max 8MB' });
    }

    const id = genId('up');
    // TODO(prod): if STORAGE_BUCKET is set, PUT to S3 and store `url` instead of `data`.
    await this.prisma.upload.create({
      data: { id, userId: user.userId, contentType: dto.contentType, data: buf },
    });
    const origin = `${req.protocol}://${req.get('host')}`;
    return { id, url: `${origin}/v1/uploads/${id}` };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Serve an uploaded file (public)' })
  async serve(@Param('id') id: string, @Res() res: Response): Promise<void> {
    const up = await this.prisma.upload.findUnique({ where: { id } });
    if (!up) throw new NotFoundException({ code: 'not_found', message: 'Upload not found' });
    if (up.url) {
      res.redirect(up.url); // stored in object storage
      return;
    }
    res.setHeader('Content-Type', up.contentType);
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.send(Buffer.from(up.data as unknown as Buffer));
  }
}
