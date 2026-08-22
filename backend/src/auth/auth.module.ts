import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { OtpService } from './otp/otp.service';
import { FirebaseAdminService } from './firebase/firebase-admin.service';
import { UsersModule } from '../users/users.module';
import { CryptoModule } from '../common/crypto/crypto.module';

@Module({
  imports: [
    UsersModule,
    CryptoModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'dev-secret'),
        signOptions: { expiresIn: config.get<string>('JWT_EXPIRES_IN', '30d') },
      }),
    }),
  ],
  providers: [AuthService, JwtStrategy, OtpService, FirebaseAdminService],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
