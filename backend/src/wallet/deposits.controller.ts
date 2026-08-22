import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { DepositsService } from './deposits.service';
import { CreateDepositDto, DepositDto, DepositMethodDto, DepositAddressDto } from './dto/deposit.dto';

@ApiTags('wallet')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('deposits')
export class DepositsController {
  constructor(private readonly deposits: DepositsService) {}

  @Get('methods')
  @ApiOperation({ summary: 'Deposit methods (crypto live; others coming soon)' })
  @ApiOkResponse({ type: [DepositMethodDto] })
  methods(): Promise<DepositMethodDto[]> {
    return this.deposits.methods();
  }

  @Get()
  @ApiOperation({ summary: 'My deposits, newest first' })
  @ApiOkResponse({ type: [DepositDto] })
  listMine(@CurrentUser() user: AuthUser): Promise<DepositDto[]> {
    return this.deposits.listMine(user.userId);
  }

  @Get('addresses')
  @ApiOperation({ summary: 'My per-network USDT deposit addresses (issued after KYC)' })
  @ApiOkResponse({ type: [DepositAddressDto] })
  addresses(@CurrentUser() user: AuthUser): Promise<DepositAddressDto[]> {
    return this.deposits.myAddresses(user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Start a deposit (crypto). Auto-confirms in test mode.' })
  @ApiOkResponse({ type: DepositDto })
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateDepositDto): Promise<DepositDto> {
    return this.deposits.create(user.userId, dto);
  }
}
