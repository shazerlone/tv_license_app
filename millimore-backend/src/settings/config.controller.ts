import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { SettingsService } from './settings.service';

/**
 * Public app config — the subset of platform settings the mobile app needs to
 * render deposit methods, leverage caps and limits. No auth required.
 */
@ApiTags('config')
@Controller('config')
export class ConfigController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Public platform config (leverage cap, limits, deposit methods)' })
  get() {
    return this.settings.publicConfig();
  }
}
