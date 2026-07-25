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
  ) {}

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
        role: Role.follower,
        creatorStatus: CreatorStatus.none,
        residenceIso: dto.residenceIso.toUpperCase(),
        residenceCountry: countryNameFromIso(dto.residenceIso),
        experience: dto.experience,
        interests: dto.interests ?? [],
      },
    });
    return this.envelope(user);
  }

  async registerCreator(dto: RegisterCreatorDto): Promise<AuthResponseDto> {
    await this.assertPhoneFree(dto.phone);
    const user = await this.prisma.user.create({
      data: {
        id: genId('u'),
        name: dto.name,
        username: await this.uniqueUsername(dto.name),
        phone: dto.phone,
        role: Role.creator,
        creatorStatus: CreatorStatus.pending, // awaits admin approval (milestone 2)
        residenceIso: dto.residenceIso.toUpperCase(),
        residenceCountry: countryNameFromIso(dto.residenceIso),
        market: dto.market,
        platform: dto.platform,
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

    return this.envelope(user);
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
  async login(email: string, password: string): Promise<AuthResponseDto> {
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
    return this.envelope(user);
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
