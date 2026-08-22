import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface SendResult {
  /** In console/dev mode, the raw code is surfaced so the app team can test. */
  devCode?: string;
}

/**
 * OTP delivery abstraction. Section 7 secret: OTP_PROVIDER_KEY (Twilio/MSG91).
 * When OTP_PROVIDER=console (default in dev, no key required) codes are logged
 * and returned to the caller as `devCode` for immediate app integration.
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger('OtpService');
  private readonly provider: string;
  private readonly codeLength: number;

  constructor(private readonly config: ConfigService) {
    this.provider = config.get<string>('OTP_PROVIDER', 'console');
    this.codeLength = Number(config.get<string>('OTP_CODE_LENGTH', '6'));
  }

  get ttlSeconds(): number {
    return Number(this.config.get<string>('OTP_CODE_TTL_SECONDS', '300'));
  }

  generateCode(): string {
    const max = 10 ** this.codeLength;
    const n = Math.floor(Math.random() * max);
    return n.toString().padStart(this.codeLength, '0');
  }

  async send(phone: string, code: string): Promise<SendResult> {
    switch (this.provider) {
      case 'twilio':
      case 'msg91':
        // Real providers are wired via OTP_PROVIDER_KEY. Until credentials are
        // present we fail loudly rather than silently dropping the message.
        if (!this.config.get<string>('OTP_PROVIDER_KEY')) {
          this.logger.error(
            `OTP_PROVIDER=${this.provider} but OTP_PROVIDER_KEY is unset; cannot send SMS.`,
          );
        }
        // TODO(milestone-1+): integrate Twilio/MSG91 HTTP send here.
        this.logger.log(`[${this.provider}] OTP → ${this.mask(phone)}`);
        return {};
      case 'console':
      default:
        this.logger.log(`[console] OTP for ${this.mask(phone)} is ${code}`);
        return { devCode: code };
    }
  }

  private mask(phone: string): string {
    return phone.replace(/.(?=.{2})/g, '•');
  }
}
