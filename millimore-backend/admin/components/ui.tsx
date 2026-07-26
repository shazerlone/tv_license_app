import { ReactNode } from 'react';

// Deterministic, tasteful avatar color from a seed (brand-adjacent hues).
const AVATAR_COLORS = [
  '#2563eb', '#7c3aed', '#0891b2', '#0d9488', '#c026d3', '#db2777', '#ea580c',
  '#4f46e5', '#0284c7', '#059669',
];

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h;
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function Avatar({ name, seed, size = 32 }: { name: string; seed?: string; size?: number }) {
  const color = AVATAR_COLORS[hash(seed || name) % AVATAR_COLORS.length];
  return (
    <div
      className="avatar"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.36,
        background: `linear-gradient(135deg, ${color}, ${color}cc)`,
      }}
    >
      {initials(name)}
    </div>
  );
}

type PillTone = 'blue' | 'green' | 'amber' | 'red' | 'slate';

const ROLE_TONE: Record<string, PillTone> = {
  admin: 'blue',
  creator: 'amber',
  follower: 'slate',
};
const STATUS_TONE: Record<string, PillTone> = {
  approved: 'green',
  connected: 'green',
  pending: 'amber',
  rejected: 'red',
  suspended: 'red',
  none: 'slate',
};

export function Pill({ tone = 'slate', plain, children }: { tone?: PillTone; plain?: boolean; children: ReactNode }) {
  return <span className={`pill ${tone === 'slate' ? '' : tone} ${plain ? 'plain' : ''}`}>{children}</span>;
}

export const RolePill = ({ role }: { role: string }) => <Pill tone={ROLE_TONE[role] ?? 'slate'}>{role}</Pill>;
export const StatusPill = ({ status }: { status: string }) => (
  <Pill tone={STATUS_TONE[status] ?? 'slate'}>{status}</Pill>
);

// Inline stroke icons (no icon-font dependency).
const I = (p: { children: ReactNode }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    {p.children}
  </svg>
);
export const Icons = {
  overview: () => (
    <I><rect x="3" y="3" width="7" height="9" rx="1.5" /><rect x="14" y="3" width="7" height="5" rx="1.5" /><rect x="14" y="12" width="7" height="9" rx="1.5" /><rect x="3" y="16" width="7" height="5" rx="1.5" /></I>
  ),
  users: () => (
    <I><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></I>
  ),
  queue: () => (
    <I><path d="M9 11l3 3L22 4" /><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" /></I>
  ),
  approved: () => (
    <I><path d="M20 6L9 17l-5-5" /></I>
  ),
  spark: () => (
    <I><path d="M13 2L3 14h7l-1 8 10-12h-7l1-8z" /></I>
  ),
  search: () => (
    <I><circle cx="11" cy="11" r="8" /><path d="M21 21l-4.3-4.3" /></I>
  ),
};
