import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { TradingAccount } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { genId } from '../common/ids';
import {
  TradingAccountDto,
  ConnectAccountDto,
  ChangeAccountPasswordDto,
} from './dto/account.dto';

@Injectable()
export class AccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
  ) {}

  toDto(a: TradingAccount): TradingAccountDto {
    return {
      id: a.id,
      brokerId: a.brokerId,
      brokerName: a.brokerName,
      accountNumber: a.accountNumber,
      masked: this.mask(a.accountNumber),
      server: a.server,
      currency: a.currency,
      balance: a.balance,
      status: a.status,
      connectedAt: a.connectedAt.toISOString(),
    };
  }

  private mask(accountNumber: string): string {
    const last4 = accountNumber.slice(-4);
    return `••••${last4}`;
  }

  async list(userId: string): Promise<TradingAccountDto[]> {
    const accounts = await this.prisma.tradingAccount.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return accounts.map((a) => this.toDto(a));
  }

  async connect(userId: string, dto: ConnectAccountDto): Promise<TradingAccountDto> {
    const broker = await this.prisma.broker.findUnique({ where: { id: dto.brokerId } });
    if (!broker) {
      throw new BadRequestException({ code: 'broker_unknown', message: 'Unknown broker' });
    }

    // TODO(milestone 6): verify credentials against the MT bridge (investor pw
    // = read-only) and fetch the real balance. For now we mark it connected.
    const account = await this.prisma.tradingAccount.create({
      data: {
        id: genId('acc'),
        userId,
        brokerId: broker.id,
        brokerName: broker.name,
        accountNumber: dto.accountNumber,
        server: dto.server,
        currency: dto.currency ?? 'USD',
        status: 'connected',
        passwordEnc: this.crypto.encrypt(dto.password),
      },
    });
    return this.toDto(account);
  }

  async remove(userId: string, id: string): Promise<void> {
    const account = await this.ownedOrThrow(userId, id);
    await this.prisma.tradingAccount.delete({ where: { id: account.id } });
  }

  async changePassword(
    userId: string,
    id: string,
    dto: ChangeAccountPasswordDto,
  ): Promise<TradingAccountDto> {
    const account = await this.ownedOrThrow(userId, id);
    if (account.passwordEnc) {
      const current = this.crypto.decrypt(account.passwordEnc);
      if (current !== dto.current) {
        throw new BadRequestException({
          code: 'password_mismatch',
          message: 'Current password is incorrect',
        });
      }
    }
    const updated = await this.prisma.tradingAccount.update({
      where: { id: account.id },
      data: { passwordEnc: this.crypto.encrypt(dto.next) },
    });
    return this.toDto(updated);
  }

  private async ownedOrThrow(userId: string, id: string): Promise<TradingAccount> {
    const account = await this.prisma.tradingAccount.findUnique({ where: { id } });
    if (!account) {
      throw new NotFoundException({ code: 'account_not_found', message: 'Account not found' });
    }
    if (account.userId !== userId) {
      throw new ForbiddenException({ code: 'forbidden', message: 'Not your account' });
    }
    return account;
  }
}
