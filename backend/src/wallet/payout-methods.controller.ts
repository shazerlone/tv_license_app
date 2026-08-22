import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PayoutMethodsService } from './payout-methods.service';
import { CreatePayoutMethodDto, PayoutMethodDto } from './dto/payout-method.dto';

@ApiTags('wallet')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('wallet/payout-methods')
export class PayoutMethodsController {
  constructor(private readonly methods: PayoutMethodsService) {}

  @Get()
  @ApiOperation({ summary: 'My saved withdrawal methods (masked)' })
  @ApiOkResponse({ type: [PayoutMethodDto] })
  list(@CurrentUser() user: AuthUser): Promise<PayoutMethodDto[]> {
    return this.methods.list(user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Add a withdrawal method (crypto / bank; encrypted)' })
  @ApiOkResponse({ type: PayoutMethodDto })
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePayoutMethodDto): Promise<PayoutMethodDto> {
    return this.methods.create(user.userId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove a withdrawal method' })
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    await this.methods.remove(user.userId, id);
    return { ok: true };
  }
}
