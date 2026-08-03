import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';
import { TransactionsService } from './transactions.service';
import { WalletDto, LedgerEntryDto, UserTxnDto } from './dto/wallet.dto';

@ApiTags('wallet')
@ApiBearerAuth('bearer')
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(
    private readonly wallet: WalletService,
    private readonly transactions: TransactionsService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'My wallet balance + default leverage (contract §wallet)' })
  @ApiOkResponse({ type: WalletDto })
  async me(@CurrentUser() user: AuthUser): Promise<WalletDto> {
    const [balance, u] = await Promise.all([
      this.wallet.balance(user.userId),
      this.prisma.user.findUnique({ where: { id: user.userId }, select: { leverage: true } }),
    ]);
    return { balance, currency: 'USD', leverage: u?.leverage ?? 100 };
  }

  @Get('ledger')
  @ApiOperation({ summary: 'My wallet ledger — recent money movements' })
  @ApiOkResponse({ type: [LedgerEntryDto] })
  ledger(@CurrentUser() user: AuthUser, @Query('limit') limit?: string): Promise<LedgerEntryDto[]> {
    const n = Math.min(200, Math.max(1, Number(limit) || 50));
    return this.wallet.ledger(user.userId, n);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'My unified transaction timeline (deposits, trades, fees, withdrawals)' })
  @ApiOkResponse({ type: [UserTxnDto] })
  transactions_(@CurrentUser() user: AuthUser, @Query('limit') limit?: string): Promise<UserTxnDto[]> {
    const n = Math.min(200, Math.max(1, Number(limit) || 50));
    return this.transactions.userTimeline(user.userId, n);
  }
}
