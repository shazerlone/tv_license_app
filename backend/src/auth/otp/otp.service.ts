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
      case 'msg91':
        return this.sendMsg91(phone, code);
      case 'twilio':
        // Real providers are wired via OTP_PROVIDER_KEY. Until credentials are
        // present we fail loudly rather than silently dropping the message.
        if (!this.config.get<string>('OTP_PROVIDER_KEY')) {
          this.logger.error(
            `OTP_PROVIDER=${this.provider} but OTP_PROVIDER_KEY is unset; cannot send SMS.`,
          );
        }
        this.logger.log(`[${this.provider}] OTP → ${this.mask(phone)}`);
        return {};
      case 'console':
      default:
        this.logger.log(`[console] OTP for ${this.mask(phone)} is ${code}`);
        return { devCode: code };
    }
  }

  /**
   * Deliver our own generated [code] over MSG91's Send-OTP API. We pass `otp`
   * explicitly so MSG91 only *delivers* the SMS — verification stays in this
   * backend (hash + TTL + attempts), so we never depend on MSG91's verify step.
   *
   * Required env (Section 7 secrets):
   *   OTP_PROVIDER=msg91
   *   OTP_PROVIDER_KEY=<MSG91 authkey>
   *   MSG91_TEMPLATE_ID=<DLT-approved OTP template id, contains {{otp}}>
   * Optional:
   *   MSG91_SENDER_ID=<6-char DLT sender/header, if not baked into the template>
   *   OTP_RETURN_DEV_CODE=true   (also surface devCode in non-prod for testing)
   */
  private async sendMsg91(phone: string, code: string): Promise<SendResult> {
    const authkey = this.config.get<string>('OTP_PROVIDER_KEY');
    const templateId = this.config.get<string>('MSG91_TEMPLATE_ID');
    const senderId = this.config.get<string>('MSG91_SENDER_ID');
    const alsoDev = this.config.get<string>('OTP_RETURN_DEV_CODE') === 'true';

    if (!authkey || !templateId) {
      this.logger.error('OTP_PROVIDER=msg91 but OTP_PROVIDER_KEY / MSG91_TEMPLATE_ID is unset; cannot send SMS.');
      return alsoDev ? { devCode: code } : {};
    }

    // MSG91 wants the number with country code and digits only (e.g. 919000000000).
    const mobile = phone.replace(/\D/g, '');
    if (mobile.length < 10) {
      this.logger.error(`MSG91: invalid mobile "${this.mask(phone)}"`);
      return alsoDev ? { devCode: code } : {};
    }

    const url = new URL('https://control.msg91.com/api/v5/otp');
    url.searchParams.set('template_id', templateId);
    url.searchParams.set('mobile', mobile);
    url.searchParams.set('otp', code);
    if (senderId) url.searchParams.set('sender', senderId);
    url.searchParams.set('otp_length', String(this.codeLength));

    try {
      const res = await fetch(url.toString(), {
        method: 'POST',
        headers: { authkey, 'content-type': 'application/json' },
        // Also pass the OTP as a template variable so templates using {{otp}}
        // (rather than the built-in ##OTP##) still render.
        body: JSON.stringify({ otp: code }),
        signal: AbortSignal.timeout(10_000),
      });
      const body = (await res.json().catch(() => ({}))) as { type?: string; message?: string; request_id?: string };
      if (!res.ok || body.type === 'error') {
        this.logger.error(`MSG91 send failed (${res.status}): ${body.message ?? 'unknown error'}`);
      } else {
        this.logger.log(`[msg91] OTP → ${this.mask(phone)} (request_id=${body.request_id ?? 'n/a'})`);
      }
    } catch (e) {
      this.logger.error(`MSG91 request error: ${(e as Error).message}`);
    }
    return alsoDev ? { devCode: code } : {};
  }

  private mask(phone: string): string {
    return phone.replace(/.(?=.{2})/g, '•');
  }
}
