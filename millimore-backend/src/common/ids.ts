import { randomBytes } from 'crypto';

/**
 * Prefixed, URL-safe, collision-resistant IDs to match the contract examples
 * ("u_123", "t_1", "acc_1", "b_1", ...). Prefix identifies the entity type.
 */
export function genId(prefix: string): string {
  // 18 hex chars ≈ 72 bits of entropy — plenty for app-scale uniqueness.
  return `${prefix}_${randomBytes(9).toString('hex')}`;
}
