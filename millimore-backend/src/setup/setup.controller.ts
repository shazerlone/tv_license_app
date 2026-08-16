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
}
