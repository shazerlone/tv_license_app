import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** GET /wallet — the user's spendable balance (margin) + default leverage. */
export class WalletDto {
  @ApiProperty({ example: 1250.75, description: 'Spendable balance = free margin.' })
  balance: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ example: 100, description: 'Default leverage (1..maxLeverage).' })
  leverage: number;
}

/** A single row in the unified transaction timeline (GET /wallet/transactions). */
export class UserTxnDto {
  @ApiProperty({ example: 'led_ab12cd34' }) id: string;
  @ApiProperty({
    example: 'deposit',
    description: 'deposit | withdrawal | trade | commission | fee | transfer',
  })
  kind: string;
  @ApiProperty({ example: 'Deposit USDT' }) title: string;
  @ApiProperty({ example: 250, description: 'Signed: credits positive, debits negative.' })
  amount: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiProperty({ example: 'completed', description: 'completed | pending | rejected' })
  status: string;
  @ApiProperty({ example: '2026-08-02T12:00:00.000Z' }) createdAt: string;
}

/** A single money movement (GET /wallet/ledger). */
export class LedgerEntryDto {
  @ApiProperty({ example: 'led_ab12cd34' }) id: string;
  @ApiProperty({
    example: 'deposit',
    description:
      'deposit | withdrawal_hold | withdrawal_refund | copy_allocate | copy_return | trade_pnl | commission | commission_earned | platform_fee | adjustment',
  })
  type: string;
  @ApiProperty({ example: 250, description: 'Signed: credits positive, debits negative.' })
  amount: number;
  @ApiProperty({ example: 1250.75 }) balanceAfter: number;
  @ApiProperty({ example: 'USD' }) currency: string;
  @ApiPropertyOptional({ nullable: true }) refId?: string | null;
  @ApiPropertyOptional({ nullable: true }) note?: string | null;
  @ApiProperty({ example: '2026-08-02T12:00:00.000Z' }) createdAt: string;
}
