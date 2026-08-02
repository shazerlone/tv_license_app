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

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Serialize a User row to the contract §3 `User` shape (no credentials). */
  toDto(u: User): UserDto {
    return {
      id: u.id,
      name: u.name,
      username: u.username,
      email: u.email,
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
    const data: Prisma.UserUpdateInput = {
      name: dto.name,
      photoUrl: dto.photoUrl,
      username: dto.username,
      market: dto.market,
      platform: dto.platform,
      addressLine: dto.addressLine,
      city: dto.city,
      postalCode: dto.postalCode,
      // Leverage is clamped to the platform max at copy time; store as given
      // (1..500 by DTO), the copy engine enforces the live ceiling.
      leverage: dto.leverage,
    };
    return this.prisma.user.update({ where: { id }, data });
  }
}
