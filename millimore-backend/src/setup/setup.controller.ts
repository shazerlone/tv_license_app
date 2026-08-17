import { Controller, Get, Query } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SetupService } from './setup.service';

/**
 * One-time setup helper (hidden from OpenAPI). Locked behind WALLET_SETUP_TOKEN.
 * Open in a browser on the deployed server:
 *   /v1/setup/master-wallet?chain=ethereum&token=YOUR_TOKEN
 */
@ApiExcludeController()
@Controller('setup')
export class SetupController {
  constructor(private readonly setup: SetupService) {}

  @Get('master-wallet')
  wallet(@Query('chain') chain: string, @Query('token') token: string) {
    return this.setup.generateWallet(chain, token);
  }

  @Get('test-addresses')
  testAddresses(@Query('token') token: string) {
    return this.setup.testAddresses(token);
  }

  @Get('test-deposit')
  testDeposit(@Query('token') token: string) {
    return this.setup.testDepositSetup(token);
  }

  @Get('test-deposit/status')
  testDepositStatus(@Query('token') token: string) {
    return this.setup.testDepositStatus(token);
  }

  @Get('last-webhooks')
  lastWebhooks(@Query('token') token: string) {
    return this.setup.lastWebhooks(token);
  }

  @Get('tatum-debug')
  tatumDebug(@Query('token') token: string) {
    return this.setup.tatumDebug(token);
  }

  @Get('rescan')
  rescan(@Query('token') token: string) {
    return this.setup.rescan(token);
  }

  @Get('sweep')
  sweep(@Query('token') token: string) {
    return this.setup.sweepTest(token);
  }
}
