import { Global, Module } from '@nestjs/common';
import { CryptoModule } from '../common/crypto/crypto.module';
import { YoutubeService } from './youtube.service';
import { YoutubeIngestService } from './youtube-ingest.service';
import { YoutubeController } from './youtube.controller';

/**
 * YouTube integration: account connect (OAuth) + live-chat ingest. Global so
 * BroadcastsService can start/stop ingest on go-live/end. RealtimeBus is global.
 */
@Global()
@Module({
  imports: [CryptoModule],
  providers: [YoutubeService, YoutubeIngestService],
  controllers: [YoutubeController],
  exports: [YoutubeService, YoutubeIngestService],
})
export class YoutubeModule {}
