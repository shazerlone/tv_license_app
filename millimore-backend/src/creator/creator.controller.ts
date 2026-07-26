import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { CreatorService } from './creator.service';
import { CreatorStatusDto, ApplyCreatorDto } from './dto/creator.dto';

@ApiTags('creator')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('creator')
export class CreatorController {
  constructor(private readonly creator: CreatorService) {}

  @Get('status')
  @ApiOperation({ summary: 'Get my creator verification status (contract §4.2)' })
  @ApiOkResponse({ type: CreatorStatusDto })
  status(@CurrentUser() user: AuthUser): Promise<CreatorStatusDto> {
    return this.creator.getStatus(user.userId);
  }

  @Post('apply')
  @ApiOperation({ summary: 'Apply for creator verification (contract §4.2)' })
  @ApiOkResponse({ type: CreatorStatusDto })
  apply(
    @CurrentUser() user: AuthUser,
    @Body() dto: ApplyCreatorDto,
  ): Promise<CreatorStatusDto> {
    return this.creator.apply(user.userId, dto);
  }
}
