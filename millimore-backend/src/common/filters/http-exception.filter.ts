import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';

/**
 * Normalizes every error into the contract shape (§1):
 *   { "error": { "code": "string", "message": "human text" } }
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exception');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'internal_error';
    let message = 'Something went wrong';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse() as
        | string
        | { message?: string | string[]; error?: string; code?: string };
      code = this.codeForStatus(status);
      if (typeof body === 'string') {
        message = body;
      } else if (body) {
        if (body.code) code = body.code;
        const m = body.message;
        message = Array.isArray(m) ? m.join(', ') : m || body.error || message;
      }
    } else {
      this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    }

    res.status(status).json({ error: { code, message } });
  }

  private codeForStatus(status: number): string {
    const map: Record<number, string> = {
      400: 'bad_request',
      401: 'unauthorized',
      403: 'forbidden',
      404: 'not_found',
      409: 'conflict',
      422: 'unprocessable',
      429: 'rate_limited',
      500: 'internal_error',
    };
    return map[status] ?? 'error';
  }
}
