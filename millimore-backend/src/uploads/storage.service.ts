import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

export interface StoredObject {
  url: string;
}

/**
 * Object storage for uploads. When STORAGE_BUCKET + STORAGE_REGION are set,
 * files go to S3 (served via STORAGE_PUBLIC_BASE_URL / CloudFront, or the S3 URL).
 * Otherwise files fall back to Postgres bytes (dev / single node) and are served
 * by GET /uploads/{id}. Same API either way — flip it on with env only.
 *
 * On ECS/Fargate, leave the access keys unset and attach an IAM task role with
 * s3:PutObject — the SDK's default credential chain picks it up (best practice).
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger('StorageService');
  private readonly bucket?: string;
  private readonly region?: string;
  private readonly publicBase?: string;
  private client?: S3Client;

  constructor(config: ConfigService) {
    this.bucket = config.get<string>('STORAGE_BUCKET') || undefined;
    this.region = config.get<string>('STORAGE_REGION') || undefined;
    this.publicBase = config.get<string>('STORAGE_PUBLIC_BASE_URL') || undefined;

    if (this.bucket && this.region) {
      const accessKeyId = config.get<string>('STORAGE_ACCESS_KEY_ID');
      const secretAccessKey = config.get<string>('STORAGE_SECRET_ACCESS_KEY');
      this.client = new S3Client({
        region: this.region,
        // If keys are omitted, the default provider chain (IAM task role) is used.
        ...(accessKeyId && secretAccessKey
          ? { credentials: { accessKeyId, secretAccessKey } }
          : {}),
      });
      this.logger.log(`Object storage: S3 bucket "${this.bucket}" (${this.region})`);
    } else {
      this.logger.log('Object storage: Postgres fallback (set STORAGE_BUCKET for S3).');
    }
  }

  get enabled(): boolean {
    return !!this.client;
  }

  async put(id: string, contentType: string, body: Buffer): Promise<StoredObject> {
    const key = `uploads/${id}`;
    await this.client!.send(
      new PutObjectCommand({
        Bucket: this.bucket!,
        Key: key,
        Body: body,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
    const base =
      this.publicBase?.replace(/\/$/, '') ??
      `https://${this.bucket}.s3.${this.region}.amazonaws.com`;
    return { url: `${base}/${key}` };
  }
}
