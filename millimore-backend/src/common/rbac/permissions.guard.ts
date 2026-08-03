import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from './require-permissions.decorator';
import { Permission, hasPermission } from './permissions';

/**
 * Enforces @RequirePermissions on admin routes. Endpoints without the decorator
 * are allowed for any admin (RolesGuard already gated role=admin). The admin's
 * `adminRole` → permission set is resolved per request (admin traffic is low).
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<Permission[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.userId;
    if (!userId) throw new ForbiddenException({ code: 'forbidden', message: 'Not authorized' });

    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { adminRole: true } });
    const missing = required.filter((p) => !hasPermission(user?.adminRole, p));
    if (missing.length > 0) {
      throw new ForbiddenException({
        code: 'insufficient_permission',
        message: `Your admin role lacks: ${missing.join(', ')}.`,
      });
    }
    return true;
  }
}
