import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'crypto';

/**
 * AES-256-GCM encryption for write-only credentials (broker/investor passwords,
 * OAuth tokens). These are stored encrypted and NEVER returned in responses
 * (contract §3 TradingAccount note, RULES: "credentials are write-only").
 *
 * Stored format: base64( iv[12] | authTag[16] | ciphertext ).
 */
@Injectable()
export class CryptoService {
  private readonly logger = new Logger('CryptoService');
  private readonly key: Buffer;

  constructor(config: ConfigService) {
    const raw = config.get<string>('CREDENTIAL_ENCRYPTION_KEY', '');
    this.key = this.deriveKey(raw);
  }

  private deriveKey(raw: string): Buffer {
    if (!raw) {
      this.logger.warn(
        'CREDENTIAL_ENCRYPTION_KEY is not set — using an ephemeral dev key. ' +
          'Encrypted credentials will not survive a restart. Set it in production.',
      );
      return randomBytes(32);
    }
    // Accept base64, hex, or arbitrary string; normalize to exactly 32 bytes.
    for (const enc of ['base64', 'hex'] as const) {
      try {
        const b = Buffer.from(raw, enc);
        if (b.length === 32) return b;
      } catch {
        /* try next */
      }
    }
    return createHash('sha256').update(raw).digest();
  }

  encrypt(plaintext: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const enc = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([iv, tag, enc]).toString('base64');
  }

  decrypt(payload: string): string {
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const enc = buf.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', this.key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(enc), decipher.final()]).toString('utf8');
  }

  /** One-way hash for OTP codes (with the same key as pepper). */
  hashCode(code: string): string {
    return createHash('sha256').update(`${code}:${this.key.toString('hex')}`).digest('hex');
  }

  /** URL-safe random token for one-time links (password reset, etc.). */
  randomToken(bytes = 32): string {
    return randomBytes(bytes).toString('base64url');
  }
}
