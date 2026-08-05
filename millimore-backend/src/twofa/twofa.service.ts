import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { CryptoService } from '../common/crypto/crypto.service';
import {
  generateBackupCodes,
  generateSecret,
  otpauthUrl,
  verifyTotp,
} from './totp';

@Injectable()
export class TwofaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: CryptoService,
  ) {}

  async status(userId: string): Promise<{ enabled: boolean }> {
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: { twofaEnabled: true } });
    return { enabled: !!u?.twofaEnabled };
  }

  /** Step 1: generate + store a secret (not yet enabled) and return the QR data. */
  async setup(userId: string): Promise<{ secret: string; otpauthUrl: string }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException({ code: 'user_not_found', message: 'User not found' });
    if (user.twofaEnabled) {
      throw new BadRequestException({ code: 'already_enabled', message: '2FA is already enabled.' });
    }
    const secret = generateSecret();
    await this.prisma.user.update({ where: { id: userId }, data: { twofaSecretEnc: this.crypto.encrypt(secret) } });
    const account = user.email ?? user.username;
    return { secret, otpauthUrl: otpauthUrl(secret, account) };
  }

  /** Step 2: confirm a code from the authenticator, enable 2FA, return backup codes. */
  async enable(userId: string, code: string): Promise<{ backupCodes: string[] }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.twofaSecretEnc) {
      throw new BadRequestException({ code: 'setup_required', message: 'Run 2FA setup first.' });
    }
    const secret = this.crypto.decrypt(user.twofaSecretEnc);
    const step = verifyTotp(secret, code);
    if (step == null) throw new BadRequestException({ code: 'invalid_code', message: 'That code is not valid.' });

    const backupCodes = generateBackupCodes();
    const hashes = await Promise.all(backupCodes.map((c) => bcrypt.hash(c, 10)));
    await this.prisma.user.update({
      where: { id: userId },
      data: { twofaEnabled: true, twofaBackupCodes: hashes, twofaLastStep: step },
    });
    return { backupCodes };
  }

  async disable(userId: string, code: string): Promise<{ ok: boolean }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.twofaEnabled) return { ok: true };
    const okCode = await this.verifyForLogin(user, code);
    if (!okCode) throw new BadRequestException({ code: 'invalid_code', message: 'That code is not valid.' });
    await this.prisma.user.update({
      where: { id: userId },
      data: { twofaEnabled: false, twofaSecretEnc: null, twofaBackupCodes: [], twofaLastStep: null },
    });
    return { ok: true };
  }

  /**
   * Verify a login second factor: a TOTP code (with anti-reuse) or a one-time
   * backup code (consumed on use). Returns true on success.
   */
  async verifyForLogin(user: User, code: string): Promise<boolean> {
    if (!user.twofaEnabled || !user.twofaSecretEnc || !code) return false;
    const clean = code.trim();

    // TOTP path
    const secret = this.crypto.decrypt(user.twofaSecretEnc);
    const step = verifyTotp(secret, clean, { afterStep: user.twofaLastStep ?? null });
    if (step != null) {
      await this.prisma.user.update({ where: { id: user.id }, data: { twofaLastStep: step } });
      return true;
    }

    // Backup-code path (one-time)
    for (const hash of user.twofaBackupCodes) {
      if (await bcrypt.compare(clean.toUpperCase(), hash)) {
        await this.prisma.user.update({
          where: { id: user.id },
          data: { twofaBackupCodes: user.twofaBackupCodes.filter((h) => h !== hash) },
        });
        return true;
      }
    }
    return false;
  }
}
