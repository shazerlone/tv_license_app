import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { countryNameFromIso } from '../common/countries';
import { UserDto } from './dto/user.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { EmailVerificationService } from './email-verification.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly emailVerification: EmailVerificationService,
  ) {}

  /** Serialize a User row to the contract §3 `User` shape (no credentials). */
  toDto(u: User): UserDto {
    return {
      id: u.id,
      name: u.name,
      username: u.username,
      email: u.email,
      emailVerified: u.emailVerified,
      emailNotifications: u.emailNotifications,
      phone: u.phone,
      photoUrl: u.photoUrl,
      role: u.role,
      creatorStatus: u.creatorStatus,
      residenceIso: u.residenceIso,
      residenceCountry: u.residenceCountry ?? countryNameFromIso(u.residenceIso),
      market: u.market,
      platform: u.platform,
      addressLine: u.addressLine,
      city: u.city,
      postalCode: u.postalCode,
      leverage: u.leverage,
      kycStatus: u.kycStatus,
      twofaEnabled: u.twofaEnabled,
      createdAt: u.createdAt.toISOString(),
    };
  }

  async findByIdOrThrow(id: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) {
      throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    }
    return user;
  }

  async updateMe(id: string, dto: UpdateMeDto): Promise<User> {
    if (dto.username) {
      const clash = await this.prisma.user.findFirst({
        where: { username: dto.username, NOT: { id } },
        select: { id: true },
      });
      if (clash) {
        throw new ConflictException({
          code: 'username_taken',
          message: 'That username is already taken',
        });
      }
    }
    // Email change: normalize, enforce uniqueness, and reset verification so the
    // new address must be re-verified. Auto-sends a code (best-effort) on change.
    let emailChanged = false;
    let normalizedEmail: string | undefined;
    if (dto.email !== undefined) {
      normalizedEmail = dto.email.trim().toLowerCase();
      const current = await this.prisma.user.findUnique({ where: { id }, select: { email: true } });
      emailChanged = (current?.email ?? null) !== normalizedEmail;
      if (emailChanged) {
        const clash = await this.prisma.user.findFirst({ where: { email: normalizedEmail, NOT: { id } }, select: { id: true } });
        if (clash) throw new ConflictException({ code: 'email_taken', message: 'That email is already in use' });
      }
    }

    const data: Prisma.UserUpdateInput = {
      name: dto.name,
      photoUrl: dto.photoUrl,
      username: dto.username,
      market: dto.market,
      platform: dto.platform,
      addressLine: dto.addressLine,
      city: dto.city,
      postalCode: dto.postalCode,
      emailNotifications: dto.emailNotifications,
      // Leverage is clamped to the platform max at copy time; store as given
      // (1..500 by DTO), the copy engine enforces the live ceiling.
      leverage: dto.leverage,
      ...(emailChanged ? { email: normalizedEmail, emailVerified: false } : {}),
    };
    const user = await this.prisma.user.update({ where: { id }, data }).catch((e) => {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({ code: 'email_taken', message: 'That email is already in use' });
      }
      throw e;
    });
    // Fire a verification code to the new address (never block the profile update).
    if (emailChanged && normalizedEmail) {
      void this.emailVerification.sendCode(id, normalizedEmail).catch(() => undefined);
    }
    return user;
  }
}
