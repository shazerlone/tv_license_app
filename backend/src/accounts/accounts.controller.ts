import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { AccountsService } from './accounts.service';
import {
  TradingAccountDto,
  ConnectAccountDto,
  ChangeAccountPasswordDto,
} from './dto/account.dto';

@ApiTags('accounts')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('accounts')
export class AccountsController {
  constructor(private readonly accounts: AccountsService) {}

  @Get()
  @ApiOperation({ summary: 'List my trading accounts (contract §4.3)' })
  @ApiOkResponse({ type: [TradingAccountDto] })
  list(@CurrentUser() user: AuthUser): Promise<TradingAccountDto[]> {
    return this.accounts.list(user.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Connect a trading account (contract §4.3)' })
  @ApiCreatedResponse({ type: TradingAccountDto })
  connect(
    @CurrentUser() user: AuthUser,
    @Body() dto: ConnectAccountDto,
  ): Promise<TradingAccountDto> {
    return this.accounts.connect(user.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Disconnect a trading account (contract §4.3)' })
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<void> {
    await this.accounts.remove(user.userId, id);
  }

  @Post(':id/password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change an account password (contract §4.3)' })
  @ApiOkResponse({ type: TradingAccountDto })
  changePassword(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ChangeAccountPasswordDto,
  ): Promise<TradingAccountDto> {
    return this.accounts.changePassword(user.userId, id, dto);
  }
}
