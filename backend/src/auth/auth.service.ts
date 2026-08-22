import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { Role, CreatorStatus, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { CryptoService } from '../common/crypto/crypto.service';
import { OtpService } from './otp/otp.service';
import { ReferralsService } from '../referrals/referrals.service';
import { TwofaService } from '../twofa/twofa.service';
import { MailService } from '../mail/mail.service';
import { EmailVerificationService } from '../users/email-verification.service';
import { FirebaseAdminService } from './firebase/firebase-admin.service';
import { genId } from '../common/ids';
import { countryNameFromIso } from '../common/countries';
import {
  RegisterFollowerDto,
  RegisterCreatorDto,
} from './dto/register.dto';
import { AuthResponseDto } from './dto/otp.dto';
import { JwtPayload } from './jwt.strategy';

@Injectable()
export class AuthService {
  private readonly logger = new Logger('AuthService');

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly crypto: CryptoService,
    private readonly otp: OtpService,
    private readonly config: ConfigService,
    private readonly referrals: ReferralsService,
    private readonly twofa: TwofaService,
    private readonly mail: MailService,
    private readonly emailVerification: EmailVerificationService,
    private readonly firebase: FirebaseAdminService,
  ) {}

  /**
   * Exchange a verified Firebase ID token (Phone Auth) for a Millimore session.
   * Matches an existing account by phone (or Firebase uid), else creates a
   * minimal follower — registration can enrich it afterward via PATCH /me.
   */
  async firebaseSignIn(idToken: string): Promise<AuthResponseDto> {
    const id = await this.firebase.verify(idToken);
    if (!id.phone) {
      throw new BadRequestException({ code: 'phone_missing', message: 'This sign-in did not include a phone number.' });
    }
    let user =
      (await this.prisma.user.findFirst({ where: { firebaseUid: id.uid } })) ??
      (await this.prisma.user.findUnique({ where: { phone: id.phone } }));
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          id: genId('u'),
          name: id.name || 'New User',
          username: await this.uniqueUsername(id.name || 'user'),
          phone: id.phone,
          firebaseUid: id.uid,
          role: Role.follower,
          creatorStatus: CreatorStatus.none,
        },
      });
    } else if (!user.firebaseUid) {
      // Link the Firebase uid to an existing (phone-matched) account.
      user = await this.prisma.user.update({ where: { id: user.id }, data: { firebaseUid: id.uid } });
    }
    if (user.banned) {
      throw new UnauthorizedException({ code: 'account_banned', message: 'Account suspended' });
    }
    return this.envelope(user);
  }

  /** Set an email at registration (unverified) + fire a verification code. Guards
   *  against a duplicate email and never fails registration on a mail hiccup. */
  private async attachEmail(userId: string, email?: string): Promise<void> {
    const e = email?.trim().toLowerCase();
    if (!e) return;
    const clash = await this.prisma.user.findFirst({ where: { email: e, NOT: { id: userId } }, select: { id: true } });
    if (clash) return; // silently skip a taken email — the user can fix it via PATCH /me
    await this.prisma.user.update({ where: { id: userId }, data: { email: e, emailVerified: false } }).catch(() => undefined);
    void this.emailVerification.sendCode(userId, e).catch(() => undefined);
  }

  /** Resolve a referral code → { referredById, referredByCode } for user create. */
  private async referralData(code?: string): Promise<{ referredById?: string; referredByCode?: string }> {
    const ref = await this.referrals.resolveReferrer(code);
    return ref ? { referredById: ref.id, referredByCode: ref.code } : {};
  }

  // ── token / envelope ───────────────────────────────────────────────
  private sign(user: User): string {
    const payload: JwtPayload = { sub: user.id, role: user.role };
    return this.jwt.sign(payload);
  }

  private envelope(user: User): AuthResponseDto {
    return { token: this.sign(user), user: this.users.toDto(user) };
  }

  // ── registration ───────────────────────────────────────────────────
  async registerFollower(dto: RegisterFollowerDto): Promise<AuthResponseDto> {
    await this.assertPhoneFree(dto.phone);
    const user = await this.prisma.user.create({
      data: {
        id: genId('u'),
        name: dto.name,
        username: await this.uniqueUsername(dto.name),
        phone: dto.phone,
        photoUrl: dto.photoUrl,
        passwordHash: dto.password ? await bcrypt.hash(dto.password, 10) : undefined,
        role: Role.follower,
        creatorStatus: CreatorStatus.none,
        residenceIso: dto.residenceIso.toUpperCase(),
        residenceCountry: countryNameFromIso(dto.residenceIso),
        experience: dto.experience,
        interests: dto.interests ?? [],
        ...(await this.referralData(dto.referralCode)),
      },
    });
    await this.attachEmail(user.id, dto.email);
    return this.envelope(await this.prisma.user.findUniqueOrThrow({ where: { id: user.id } }));
  }

  async registerCreator(dto: RegisterCreatorDto): Promise<AuthResponseDto> {
    await this.assertPhoneFree(dto.phone);
    const user = await this.prisma.user.create({
      data: {
        id: genId('u'),
        name: dto.name,
        username: await this.uniqueUsername(dto.name),
        phone: dto.phone,
        passwordHash: dto.password ? await bcrypt.hash(dto.password, 10) : undefined,
        role: Role.creator,
        creatorStatus: CreatorStatus.pending, // awaits admin approval (milestone 2)
        residenceIso: dto.residenceIso.toUpperCase(),
        residenceCountry: countryNameFromIso(dto.residenceIso),
        market: dto.market,
        platform: dto.platform,
        ...(await this.referralData(dto.referralCode)),
      },
    });

    const v = dto.verification;
    await this.prisma.creatorApplication.create({
      data: {
        id: genId('capp'),
        userId: user.id,
        status: CreatorStatus.pending,
        market: dto.market,
        platform: dto.platform,
        verificationPlatform: v.platform,
        server: v.server,
        account: v.account,
        statementUrl: v.statementUrl,
        investorPasswordEnc: v.investorPassword
          ? this.crypto.encrypt(v.investorPassword)
          : null,
      },
    });

    await this.attachEmail(user.id, dto.email);
    return this.envelope(await this.prisma.user.findUniqueOrThrow({ where: { id: user.id } }));
  }

  // ── OTP ────────────────────────────────────────────────────────────
  async otpRequest(phone: string): Promise<{ requestId: string; devCode?: string }> {
    const code = this.otp.generateCode();
    const requestId = genId('otp');
    const expiresAt = new Date(Date.now() + this.otp.ttlSeconds * 1000);

    await this.prisma.otpRequest.create({
      data: {
        id: requestId,
        phone,
        codeHash: this.crypto.hashCode(code),
        expiresAt,
      },
    });

    const { devCode } = await this.otp.send(phone, code);
    return { requestId, devCode };
  }

  async otpVerify(requestId: string, code: string): Promise<AuthResponseDto> {
    const req = await this.prisma.otpRequest.findUnique({ where: { id: requestId } });
    if (!req) {
      throw new BadRequestException({
        code: 'otp_invalid',
        message: 'Invalid or expired verification request',
      });
    }
    if (req.consumedAt) {
      throw new BadRequestException({ code: 'otp_used', message: 'Code already used' });
    }
    if (req.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException({ code: 'otp_expired', message: 'Code expired' });
    }
    if (req.attempts >= 5) {
      throw new BadRequestException({
        code: 'otp_too_many_attempts',
        message: 'Too many attempts, request a new code',
      });
    }

    if (req.codeHash !== this.crypto.hashCode(code)) {
      await this.prisma.otpRequest.update({
        where: { id: requestId },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException({ code: 'otp_mismatch', message: 'Incorrect code' });
    }

    await this.prisma.otpRequest.update({
      where: { id: requestId },
      data: { consumedAt: new Date() },
    });

    // Phone-first login: an existing account signs in; otherwise create a
    // minimal follower (registration can enrich it afterward via PATCH /me).
    let user = await this.prisma.user.findUnique({ where: { phone: req.phone } });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          id: genId('u'),
          name: 'New User',
          username: await this.uniqueUsername('user'),
          phone: req.phone,
          role: Role.follower,
          creatorStatus: CreatorStatus.none,
        },
      });
    }
    return this.envelope(user);
  }

  // ── password login ─────────────────────────────────────────────────
  async login(email: string, password: string, twofaCode?: string): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException({
        code: 'invalid_credentials',
        message: 'Incorrect email or password',
      });
    }
    if (user.banned) {
      throw new UnauthorizedException({ code: 'account_banned', message: 'Account suspended' });
    }
    // Second factor: if enabled, a valid TOTP or backup code is required.
    if (user.twofaEnabled) {
      if (!twofaCode) {
        throw new UnauthorizedException({ code: 'twofa_required', message: 'Enter your 2FA code.' });
      }
      if (!(await this.twofa.verifyForLogin(user, twofaCode))) {
        throw new UnauthorizedException({ code: 'twofa_invalid', message: 'Invalid 2FA code.' });
      }
    }
    return this.envelope(user);
  }

  // ── password reset / change ─────────────────────────────────────────
  private resetTtlMinutes(): number {
    return Number(this.config.get<string>('PASSWORD_RESET_TTL_MINUTES', '30'));
  }

  /**
   * Start a password reset. Always returns ok (never reveals whether the email
   * exists — no account enumeration). When email isn't configured
   * (MAIL_PROVIDER=console) the raw token is returned as `devToken` so the app
   * team can test end-to-end, mirroring the OTP `devCode` behaviour.
   */
  async forgotPassword(email: string): Promise<{ ok: true; devToken?: string }> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    // Only email/password accounts can reset; phone-only users use OTP login.
    if (!user || !user.passwordHash) return { ok: true };

    const token = this.crypto.randomToken();
    const ttl = this.resetTtlMinutes();
    await this.prisma.passwordReset.create({
      data: {
        id: genId('pr'),
        userId: user.id,
        tokenHash: this.crypto.hashCode(token),
        expiresAt: new Date(Date.now() + ttl * 60_000),
      },
    });
    const delivered = await this.mail.sendPasswordReset(email, { name: user.name ?? undefined, token, ttlMinutes: ttl });
    if (!delivered) this.logger.log(`[console] password reset token for ${email}: ${token}`);
    return delivered ? { ok: true } : { ok: true, devToken: token };
  }

  /** Complete a reset with the emailed token; sets a new password. */
  async resetPassword(token: string, newPassword: string): Promise<{ ok: true }> {
    const row = await this.prisma.passwordReset.findFirst({
      where: { tokenHash: this.crypto.hashCode(token), usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!row) {
      throw new BadRequestException({ code: 'reset_token_invalid', message: 'This reset link is invalid or has expired.' });
    }
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: row.userId }, data: { passwordHash } }),
      this.prisma.passwordReset.update({ where: { id: row.id }, data: { usedAt: new Date() } }),
      // Invalidate any other outstanding reset tokens for this user.
      this.prisma.passwordReset.updateMany({
        where: { userId: row.userId, usedAt: null },
        data: { usedAt: new Date() },
      }),
    ]);
    const user = await this.prisma.user.findUnique({ where: { id: row.userId } });
    if (user?.email) {
      void this.mail.sendSecurityAlert(user.email, {
        name: user.name ?? undefined,
        title: 'Your password was reset',
        detail: 'Your Millimore password was just changed using a reset link.',
      });
    }
    return { ok: true };
  }

  /** Change password for a logged-in user (requires the current password). */
  async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<{ ok: true }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.passwordHash || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
      throw new BadRequestException({ code: 'invalid_credentials', message: 'Your current password is incorrect.' });
    }
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    if (user.email) {
      void this.mail.sendSecurityAlert(user.email, {
        name: user.name ?? undefined,
        title: 'Your password was changed',
        detail: 'Your Millimore password was just changed from your account settings.',
      });
    }
    return { ok: true };
  }

  // ── social login ───────────────────────────────────────────────────
  // NOTE: milestone-1 decodes the provider token to extract subject/email.
  // Signature verification against Apple/Google JWKS must be added before prod.
  async socialApple(identityToken: string): Promise<AuthResponseDto> {
    const claims = this.decodeJwt(identityToken);
    return this.upsertSocial('apple', claims.sub, claims.email, claims.name);
  }

  async socialGoogle(idToken: string): Promise<AuthResponseDto> {
    const claims = this.decodeJwt(idToken);
    return this.upsertSocial('google', claims.sub, claims.email, claims.name);
  }

  private async upsertSocial(
    provider: 'apple' | 'google',
    subject?: string,
    email?: string,
    name?: string,
  ): Promise<AuthResponseDto> {
    if (!subject) {
      throw new BadRequestException({
        code: 'social_token_invalid',
        message: 'Could not read identity from provider token',
      });
    }
    const subjectField = provider === 'apple' ? 'appleSubject' : 'googleSubject';
    let user = await this.prisma.user.findFirst({
      where: { OR: [{ [subjectField]: subject }, ...(email ? [{ email }] : [])] },
    });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          id: genId('u'),
          name: name || 'New User',
          username: await this.uniqueUsername(name || 'user'),
          email: email ?? null,
          [subjectField]: subject,
          role: Role.follower,
          creatorStatus: CreatorStatus.none,
        },
      });
    } else if (!user[subjectField as keyof User]) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { [subjectField]: subject },
      });
    }
    return this.envelope(user);
  }

  // ── helpers ────────────────────────────────────────────────────────
  private async assertPhoneFree(phone: string): Promise<void> {
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing) {
      throw new ConflictException({
        code: 'phone_in_use',
        message: 'An account with this phone already exists',
      });
    }
  }

  private async uniqueUsername(seed: string): Promise<string> {
    const base =
      seed
        .toLowerCase()
        .normalize('NFKD')
        .replace(/[^a-z0-9]/g, '')
        .slice(0, 24) || 'user';
    for (let i = 0; i < 6; i++) {
      const candidate = i === 0 ? base : `${base}${Math.floor(Math.random() * 10000)}`;
      const taken = await this.prisma.user.findUnique({ where: { username: candidate } });
      if (!taken) return candidate;
    }
    return `${base}${genId('').replace('_', '')}`.slice(0, 30);
  }

  private decodeJwt(token: string): { sub?: string; email?: string; name?: string } {
    try {
      const [, payload] = token.split('.');
      if (!payload) throw new Error('malformed');
      const json = Buffer.from(payload, 'base64url').toString('utf8');
      const claims = JSON.parse(json);
      return { sub: claims.sub, email: claims.email, name: claims.name };
    } catch {
      throw new BadRequestException({
        code: 'social_token_invalid',
        message: 'Malformed provider token',
      });
    }
  }
}
