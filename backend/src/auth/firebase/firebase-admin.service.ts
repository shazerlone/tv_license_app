import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp, App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

export interface FirebaseIdentity {
  uid: string;
  phone?: string;
  email?: string;
  name?: string;
}

/**
 * Verifies Firebase ID tokens (Phone Auth). Google delivers the OTP SMS
 * worldwide — including India — with no DLT on our side; the client signs in
 * with the Firebase SDK and sends us the resulting ID token, which we verify
 * here and exchange for a Millimore session.
 *
 * Credentials (Section 7 secret) — one of:
 *   FIREBASE_SERVICE_ACCOUNT       raw JSON of a service-account key
 *   FIREBASE_SERVICE_ACCOUNT_B64   the same JSON, base64-encoded (env-friendly)
 * Generate it in Firebase console → Project settings → Service accounts →
 * Generate new private key.
 */
@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger('FirebaseAdminService');
  private app?: App;
  private initTried = false;

  constructor(private readonly config: ConfigService) {}

  get enabled(): boolean {
    return !!this.ensureApp();
  }

  private ensureApp(): App | undefined {
    if (this.app) return this.app;
    if (this.initTried) return undefined;
    this.initTried = true;

    const raw =
      this.config.get<string>('FIREBASE_SERVICE_ACCOUNT') ||
      this.decodeB64(this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_B64'));
    if (!raw) {
      this.logger.warn('Firebase Phone Auth disabled: no FIREBASE_SERVICE_ACCOUNT[_B64] set.');
      return undefined;
    }
    try {
      const svc = JSON.parse(raw) as { project_id: string; client_email: string; private_key: string };
      const existing = getApps().find((a) => a.name === 'phone-auth');
      this.app =
        existing ??
        initializeApp(
          {
            credential: cert({
              projectId: svc.project_id,
              clientEmail: svc.client_email,
              // Env vars flatten "\n" to literal backslash-n — restore real newlines.
              privateKey: svc.private_key.replace(/\\n/g, '\n'),
            }),
          },
          'phone-auth',
        );
      this.logger.log(`Firebase Phone Auth ready (project ${svc.project_id}).`);
      return this.app;
    } catch (e) {
      this.logger.error(`Firebase init failed: ${(e as Error).message}`);
      return undefined;
    }
  }

  private decodeB64(v?: string): string | undefined {
    if (!v) return undefined;
    try {
      return Buffer.from(v, 'base64').toString('utf8');
    } catch {
      return undefined;
    }
  }

  /** Verify a client ID token and return the identity, or throw 401. */
  async verify(idToken: string): Promise<FirebaseIdentity> {
    const app = this.ensureApp();
    if (!app) {
      throw new UnauthorizedException({ code: 'firebase_unavailable', message: 'Phone sign-in is not configured.' });
    }
    try {
      const decoded = await getAuth(app).verifyIdToken(idToken);
      return {
        uid: decoded.uid,
        phone: decoded.phone_number,
        email: decoded.email,
        name: (decoded.name as string | undefined) ?? undefined,
      };
    } catch (e) {
      this.logger.warn(`ID token verify failed: ${(e as Error).message}`);
      throw new UnauthorizedException({ code: 'firebase_token_invalid', message: 'Could not verify your phone sign-in.' });
    }
  }
}
