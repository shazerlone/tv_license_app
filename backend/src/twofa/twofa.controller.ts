import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { TwofaService } from './twofa.service';

class CodeDto {
  @ApiProperty({ example: '287082' })
  @IsString() @MinLength(4) @MaxLength(20)
  code: string;
}

@ApiTags('2fa')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('2fa')
export class TwofaController {
  constructor(private readonly twofa: TwofaService) {}

  @Get()
  @ApiOperation({ summary: 'Is 2FA enabled on my account?' })
  status(@CurrentUser() u: AuthUser) {
    return this.twofa.status(u.userId);
  }

  @Post('setup')
  @ApiOperation({ summary: 'Start 2FA setup — returns secret + otpauth URL for the QR' })
  setup(@CurrentUser() u: AuthUser) {
    return this.twofa.setup(u.userId);
  }

  @Post('enable')
  @ApiOperation({ summary: 'Confirm a code to enable 2FA — returns one-time backup codes' })
  enable(@CurrentUser() u: AuthUser, @Body() dto: CodeDto) {
    return this.twofa.enable(u.userId, dto.code);
  }

  @Post('disable')
  @ApiOperation({ summary: 'Disable 2FA (needs a valid code or backup code)' })
  disable(@CurrentUser() u: AuthUser, @Body() dto: CodeDto) {
    return this.twofa.disable(u.userId, dto.code);
  }
}
