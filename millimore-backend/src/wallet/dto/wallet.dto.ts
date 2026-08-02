import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** GET /wallet — the user's spendable balance. */
export class WalletDto {
  @ApiProperty({ example: 1250.75 }) balance: number;
  @ApiProperty({ example: 'USD' }) currency: string;
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
