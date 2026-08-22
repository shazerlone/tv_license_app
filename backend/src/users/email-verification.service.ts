import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { genId } from '../common/ids';

/**
 * Email verification via a short-lived OTP code emailed to the address the user
 * enters (at registration or via PATCH /me). Only the code hash is stored. On a
 * correct code we set User.emailVerified — but only if the address still matches
 * the one the code was issued for (so changing email re-requires verification).
 */
@Injectable()
export class EmailVerificationService {
  private readonly logger = new Logger('EmailVerificationService');

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly crypto: CryptoService,
  ) {}

  private ttlMinutes(): number {
    const n = Number(process.env.EMAIL_VERIFY_TTL_MINUTES ?? 15);
    return Number.isFinite(n) && n > 0 ? n : 15;
  }

  private genCode(): string {
    return Math.floor(Math.random() * 1_000_000).toString().padStart(6, '0');
  }

  /** Issue + email a verification code for the user's (current or given) email. */
  async sendCode(userId: string, emailOverride?: string): Promise<{ ok: true; devCode?: string }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { email: true, name: true } });
    const email = (emailOverride ?? user?.email ?? '').trim();
    if (!email) throw new BadRequestException({ code: 'no_email', message: 'Add an email address first.' });

    const code = this.genCode();
    const ttl = this.ttlMinutes();
    await this.prisma.emailVerification.create({
      data: { id: genId('ev'), userId, email, codeHash: this.crypto.hashCode(code), expiresAt: new Date(Date.now() + ttl * 60_000) },
    });
    const delivered = await this.mail.sendEmailVerification(email, { name: user?.name ?? undefined, code, ttlMinutes: ttl });
    if (!delivered) this.logger.log(`[console] email verification code for ${email}: ${code}`);
    // Surface the code only in non-production when the mailer isn't wired, so the app can test.
    return { ok: true, ...(!delivered && process.env.NODE_ENV !== 'production' ? { devCode: code } : {}) };
  }

  /** Confirm a code; marks the user's email verified when it matches. */
  async verify(userId: string, code: string): Promise<{ ok: true; emailVerified: true }> {
    const rec = await this.prisma.emailVerification.findFirst({
      where: { userId, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!rec) throw new BadRequestException({ code: 'code_invalid', message: 'No pending verification. Request a new code.' });
    if (rec.expiresAt.getTime() < Date.now()) throw new BadRequestException({ code: 'code_expired', message: 'Code expired. Request a new one.' });
    if (rec.attempts >= 5) throw new BadRequestException({ code: 'too_many_attempts', message: 'Too many attempts. Request a new code.' });
    if (rec.codeHash !== this.crypto.hashCode(code)) {
      await this.prisma.emailVerification.update({ where: { id: rec.id }, data: { attempts: { increment: 1 } } });
      throw new BadRequestException({ code: 'code_mismatch', message: 'Incorrect code.' });
    }
    await this.prisma.emailVerification.update({ where: { id: rec.id }, data: { consumedAt: new Date() } });
    // Only flip the flag if the user's current email still matches the verified one.
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
    if (user?.email && user.email === rec.email) {
      await this.prisma.user.update({ where: { id: userId }, data: { emailVerified: true } });
    }
    return { ok: true, emailVerified: true };
  }
}
