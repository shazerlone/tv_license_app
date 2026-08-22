import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SettingsService } from './settings.service';
import { PublicConfigDto } from './dto/config.dto';

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
  @ApiOkResponse({ type: PublicConfigDto })
  get(): Promise<PublicConfigDto> {
    return this.settings.publicConfig();
  }
}
