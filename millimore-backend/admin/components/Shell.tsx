'use client';

import { ReactNode, useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { apiFetch, getStoredUser } from '../lib/api';
import { isAuthed, logout } from '../lib/auth';
import { Avatar, Icons } from './ui';

const NAV = [
  { href: '/', label: 'Overview', icon: Icons.overview },
  { href: '/analytics', label: 'Analytics', icon: Icons.spark, perm: 'analytics.read' },
  { href: '/traders', label: 'Traders', icon: Icons.spark, perm: 'traders.read' },
  { href: '/users', label: 'Users', icon: Icons.users, perm: 'users.read' },
  { href: '/creators', label: 'Creator queue', icon: Icons.queue, perm: 'creators.approve' },
  { href: '/transactions', label: 'Transactions', icon: Icons.spark, perm: 'payouts.approve' },
  { href: '/payouts', label: 'Payouts', icon: Icons.approved, perm: 'payouts.approve' },
  { href: '/kyc', label: 'KYC', icon: Icons.approved, perm: 'kyc.decide' },
  { href: '/referrals', label: 'Referrals', icon: Icons.spark, perm: 'referrals.read' },
  { href: '/support', label: 'Support', icon: Icons.queue, perm: 'support.write' },
  { href: '/announcements', label: 'Announcements', icon: Icons.spark, perm: 'announcements.write' },
  { href: '/team', label: 'Team', icon: Icons.users, perm: 'admins.manage' },
  { href: '/audit', label: 'Audit log', icon: Icons.queue, perm: 'audit.read' },
  { href: '/security', label: 'Security', icon: Icons.approved },
  { href: '/settings', label: 'Settings', icon: Icons.users, perm: 'settings.write' },
];

const TITLES: Record<string, string> = {
  '/': 'Overview',
  '/analytics': 'Analytics',
  '/traders': 'Traders',
  '/users': 'Users',
  '/creators': 'Creator verification',
  '/transactions': 'Transactions',
  '/payouts': 'Payouts',
  '/kyc': 'KYC',
  '/referrals': 'Referrals',
  '/support': 'Support',
  '/announcements': 'Announcements',
  '/team': 'Team',
  '/audit': 'Audit log',
  '/security': 'Security',
  '/settings': 'Settings',
};

export default function Shell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [pending, setPending] = useState<number | null>(null);
  const [perms, setPerms] = useState<string[] | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const user = getStoredUser();

  useEffect(() => {
    if (!isAuthed()) {
      router.replace('/login');
      return;
    }
    setReady(true);
    apiFetch<{ permissions: string[] }>('/admin/me/permissions')
      .then((r) => setPerms(r.permissions))
      .catch(() => setPerms([]));
    apiFetch<any[]>('/admin/creators/pending')
      .then((rows) => setPending(rows.length))
      .catch(() => setPending(null));
  }, [router]);

  // Show a nav item only if the admin holds its permission (Overview: always).
  const canSee = (perm?: string) => !perm || perms === null || perms.includes(perm);

  // Close the drawer whenever the route changes.
  useEffect(() => setMenuOpen(false), [pathname]);

  if (!ready) return <div className="empty">Loading…</div>;

  const nav = (
    <>
      <div className="brand">
        milli<b>more</b>
      </div>
      <div className="nav-label">Platform</div>
      {NAV.filter((n) => canSee((n as any).perm)).map((n) => {
        const active = n.href === '/' ? pathname === '/' : pathname.startsWith(n.href);
        const Icon = n.icon;
        return (
          <Link key={n.href} href={n.href} className={`navlink ${active ? 'active' : ''}`}>
            <Icon />
            <span>{n.label}</span>
            {n.href === '/creators' && pending ? <span className="count">{pending}</span> : null}
          </Link>
        );
      })}
    </>
  );

  return (
    <div className="app">
      {menuOpen && <div className="backdrop" onClick={() => setMenuOpen(false)} />}
      <aside className={`sidebar ${menuOpen ? 'open' : ''}`}>{nav}</aside>

      <div className="main">
        <div className="topbar">
          <button
            className="hamburger"
            aria-label="Menu"
            onClick={() => setMenuOpen((v) => !v)}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M3 6h18M3 12h18M3 18h18" />
            </svg>
          </button>
          <div className="topbar-brand">
            milli<b>more</b>
          </div>
          <div className="title">{TITLES[pathname] ?? 'Admin'}</div>
          <div className="spacer" />
          <div className="row" style={{ gap: 12 }}>
            <div className="topbar-user">
              <div style={{ fontWeight: 600, fontSize: 13 }}>{user?.name ?? 'Admin'}</div>
              <div className="muted" style={{ fontSize: 12 }}>
                {user?.email}
              </div>
            </div>
            <Avatar name={user?.name ?? 'Admin'} seed={user?.id} size={36} />
            <button
              className="btn ghost sm logout-btn"
              onClick={() => {
                logout();
                router.replace('/login');
              }}
            >
              Log out
            </button>
          </div>
        </div>
        <div className="content">{children}</div>
      </div>
    </div>
  );
}
