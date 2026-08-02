import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { WalletService } from './wallet.service';
import { WalletDto, LedgerEntryDto } from './dto/wallet.dto';

@ApiTags('wallet')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'My wallet balance (contract §wallet)' })
  @ApiOkResponse({ type: WalletDto })
  async me(@CurrentUser() user: AuthUser): Promise<WalletDto> {
    const balance = await this.wallet.balance(user.userId);
    return { balance, currency: 'USD' };
  }

  @Get('ledger')
  @ApiOperation({ summary: 'My wallet ledger — recent money movements' })
  @ApiOkResponse({ type: [LedgerEntryDto] })
  ledger(@CurrentUser() user: AuthUser, @Query('limit') limit?: string): Promise<LedgerEntryDto[]> {
    const n = Math.min(200, Math.max(1, Number(limit) || 50));
    return this.wallet.ledger(user.userId, n);
  }
}
