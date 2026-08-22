/**
 * Back-office RBAC (contract §admin-roles). Named admin roles map to permission
 * sets, matching how broker CRMs (B2Core) group staff by responsibility. A
 * legacy admin with no `adminRole` is treated as superadmin (backward compatible).
 */

export const PERMISSIONS = [
  'analytics.read',
  'traders.read',
  'users.read',
  'users.write', // ban/freeze/role/notes
  'wallet.adjust', // manual balance credit/debit
  'creators.approve',
  'payouts.approve', // deposits + withdrawals decisions
  'treasury.read', // crypto treasury / sweep tracker (read)
  'treasury.sweep', // trigger consolidation sweeps
  'kyc.decide',
  'referrals.read',
  'support.write',
  'announcements.write',
  'audit.read',
  'settings.write',
  'admins.manage', // assign admin roles
] as const;

export type Permission = (typeof PERMISSIONS)[number];

export const ADMIN_ROLES = ['superadmin', 'finance', 'compliance', 'support', 'analyst'] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

const ALL: Permission[] = [...PERMISSIONS];

export const ROLE_PERMISSIONS: Record<AdminRole, Permission[]> = {
  superadmin: ALL,
  finance: ['analytics.read', 'traders.read', 'users.read', 'wallet.adjust', 'payouts.approve', 'treasury.read', 'treasury.sweep', 'referrals.read'],
  compliance: ['users.read', 'traders.read', 'kyc.decide', 'payouts.approve', 'audit.read'],
  support: ['users.read', 'traders.read', 'support.write', 'announcements.write'],
  analyst: ['analytics.read', 'traders.read', 'users.read', 'referrals.read', 'audit.read'],
};

/** Resolve an adminRole (or null legacy admin) to its permission set. */
export function permissionsFor(adminRole?: string | null): Permission[] {
  if (!adminRole) return ALL; // legacy admin = superadmin
  return ROLE_PERMISSIONS[adminRole as AdminRole] ?? [];
}

export function hasPermission(adminRole: string | null | undefined, perm: Permission): boolean {
  return permissionsFor(adminRole).includes(perm);
}
