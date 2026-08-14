import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

export interface MailMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
}

/**
 * Transactional email seam. Gated by `MAIL_PROVIDER`:
 *   - console (default): logs the email; nothing is sent (dev/offline).
 *   - smtp: sends via SMTP (works with Amazon SES SMTP, SendGrid, Mailgun, …).
 *
 * Every giant fintech emails password resets, security alerts and receipts; this
 * is the one module they all flow through. Swap the transport (SES API, HTTP
 * provider) here without touching callers. `send` never throws into the request
 * path — a mail failure must not fail the user's action.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger('MailService');
  private readonly provider: string;
  private readonly from: string;
  private transport?: nodemailer.Transporter;

  constructor(private readonly config: ConfigService) {
    this.provider = this.config.get<string>('MAIL_PROVIDER', 'console').toLowerCase();
    this.from = this.config.get<string>('MAIL_FROM', 'Millimore <no-reply@millimore.app>');
  }

  get enabled(): boolean {
    return this.provider === 'smtp';
  }

  private smtp(): nodemailer.Transporter {
    if (!this.transport) {
      this.transport = nodemailer.createTransport({
        host: this.config.get<string>('MAIL_SMTP_HOST'),
        port: Number(this.config.get<string>('MAIL_SMTP_PORT', '587')),
        secure: this.config.get<string>('MAIL_SMTP_SECURE', 'false') === 'true',
        auth: {
          user: this.config.get<string>('MAIL_SMTP_USER'),
          pass: this.config.get<string>('MAIL_SMTP_PASS'),
        },
      });
    }
    return this.transport;
  }

  /** Send an email. Returns true if handed off to a transport, false otherwise. */
  async send(msg: MailMessage): Promise<boolean> {
    try {
      if (!this.enabled) {
        this.logger.log(`[console] email → ${msg.to} · ${msg.subject}`);
        return false;
      }
      await this.smtp().sendMail({ from: this.from, ...msg });
      return true;
    } catch (err) {
      this.logger.warn(`email to ${msg.to} failed: ${String(err)}`);
      return false;
    }
  }

  // ── templates ────────────────────────────────────────────────────────
  async sendPasswordReset(to: string, opts: { name?: string; token: string; ttlMinutes: number }): Promise<boolean> {
    const base = this.config.get<string>('MAIL_RESET_URL_BASE', 'https://millimore.app/reset');
    const link = `${base}?token=${encodeURIComponent(opts.token)}`;
    const hi = opts.name ? `Hi ${opts.name},` : 'Hi,';
    return this.send({
      to,
      subject: 'Reset your Millimore password',
      text: `${hi}\n\nUse this code to reset your password: ${opts.token}\nOr open: ${link}\n\nThis expires in ${opts.ttlMinutes} minutes. If you didn't request it, ignore this email.`,
      html: this.wrap(
        `<p>${hi}</p>
         <p>Use this code to reset your password:</p>
         <p style="font-size:22px;font-weight:700;letter-spacing:1px;margin:16px 0">${opts.token}</p>
         <p><a href="${link}" style="color:#2563EB">Reset your password</a></p>
         <p style="color:#64748B;font-size:13px">This link expires in ${opts.ttlMinutes} minutes. If you didn't request it, you can safely ignore this email.</p>`,
      ),
    });
  }

  async sendSecurityAlert(to: string, opts: { name?: string; title: string; detail: string }): Promise<boolean> {
    const hi = opts.name ? `Hi ${opts.name},` : 'Hi,';
    return this.send({
      to,
      subject: `Security alert: ${opts.title}`,
      text: `${hi}\n\n${opts.detail}\n\nIf this wasn't you, reset your password and contact support immediately.`,
      html: this.wrap(
        `<p>${hi}</p>
         <p><strong>${opts.title}</strong></p>
         <p>${opts.detail}</p>
         <p style="color:#64748B;font-size:13px">If this wasn't you, reset your password and contact support immediately.</p>`,
      ),
    });
  }

  /** Minimal, brand-consistent HTML shell (light, Inter, restrained accent). */
  private wrap(inner: string): string {
    return `<div style="font-family:Inter,-apple-system,Segoe UI,Roboto,sans-serif;max-width:520px;margin:0 auto;padding:24px;color:#0F172A">
      <div style="font-weight:800;font-size:20px;letter-spacing:-0.02em;margin-bottom:16px">Millimore</div>
      <div style="background:#FFFFFF;border:1px solid #E2E8F0;border-radius:14px;padding:24px">${inner}</div>
      <p style="color:#94A3B8;font-size:12px;margin-top:16px">© Millimore</p>
    </div>`;
  }
}
