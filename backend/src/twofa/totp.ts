import { createHmac, randomBytes } from 'crypto';

/**
 * TOTP (RFC 6238) — pure functions, no external deps. 6-digit codes, 30s step,
 * HMAC-SHA1. Verification accepts ±1 window for clock drift (~±90s), per the
 * spec's guidance, and returns the matched step so the caller can block reuse.
 */

const STEP = 30;
const DIGITS = 6;
const B32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** Base32 (RFC 4648, no padding) — the format authenticator apps expect. */
export function base32Encode(buf: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of buf) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += B32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += B32_ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(s: string): Buffer {
  const clean = s.toUpperCase().replace(/=+$/, '').replace(/\s/g, '');
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const ch of clean) {
    const idx = B32_ALPHABET.indexOf(ch);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

/** A fresh 20-byte secret, base32-encoded. */
export function generateSecret(): string {
  return base32Encode(randomBytes(20));
}

/** The counter (step) for a given time. */
export function stepFor(timeMs = Date.now()): number {
  return Math.floor(timeMs / 1000 / STEP);
}

function codeForCounter(secret: Buffer, counter: number): string {
  const buf = Buffer.alloc(8);
  // 64-bit big-endian counter.
  buf.writeUInt32BE(Math.floor(counter / 2 ** 32), 0);
  buf.writeUInt32BE(counter >>> 0, 4);
  const hmac = createHmac('sha1', secret).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const bin =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return (bin % 10 ** DIGITS).toString().padStart(DIGITS, '0');
}

/** Current code for a base32 secret (used in tests / QR preview). */
export function totp(secretB32: string, timeMs = Date.now()): string {
  return codeForCounter(base32Decode(secretB32), stepFor(timeMs));
}

/**
 * Verify a code against a base32 secret with ±window drift tolerance. Returns
 * the matched step (so the caller can reject reuse via `afterStep`), or null.
 */
export function verifyTotp(
  secretB32: string,
  code: string,
  opts: { window?: number; afterStep?: number | null; timeMs?: number } = {},
): number | null {
  const window = opts.window ?? 1;
  const secret = base32Decode(secretB32);
  const current = stepFor(opts.timeMs);
  const clean = code.replace(/\s/g, '');
  for (let i = -window; i <= window; i++) {
    const step = current + i;
    if (opts.afterStep != null && step <= opts.afterStep) continue; // no reuse
    if (codeForCounter(secret, step) === clean) return step;
  }
  return null;
}

/** otpauth:// URI for the authenticator app QR. */
export function otpauthUrl(secretB32: string, account: string, issuer = 'Millimore'): string {
  const label = encodeURIComponent(`${issuer}:${account}`);
  const params = new URLSearchParams({ secret: secretB32, issuer, algorithm: 'SHA1', digits: '6', period: '30' });
  return `otpauth://totp/${label}?${params.toString()}`;
}

/** Human-friendly backup codes (10 × 8 chars, grouped). */
export function generateBackupCodes(count = 10): string[] {
  const codes: string[] = [];
  for (let i = 0; i < count; i++) {
    const raw = randomBytes(5).toString('hex').toUpperCase().slice(0, 8); // 8 hex chars
    codes.push(`${raw.slice(0, 4)}-${raw.slice(4)}`);
  }
  return codes;
}
