'use client';

import { ReactNode, useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { apiFetch, getStoredUser } from '../lib/api';
import { isAuthed, logout } from '../lib/auth';
import { Avatar, Icons } from './ui';

const NAV = [
  { href: '/', label: 'Overview', icon: Icons.overview },
  { href: '/users', label: 'Users', icon: Icons.users },
  { href: '/creators', label: 'Creator queue', icon: Icons.queue },
];

const TITLES: Record<string, string> = {
  '/': 'Overview',
  '/users': 'Users',
  '/creators': 'Creator verification',
};

export default function Shell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [pending, setPending] = useState<number | null>(null);
  const user = getStoredUser();

  useEffect(() => {
    if (!isAuthed()) {
      router.replace('/login');
      return;
    }
    setReady(true);
    apiFetch<any[]>('/admin/creators/pending')
      .then((rows) => setPending(rows.length))
      .catch(() => setPending(null));
  }, [router]);

  if (!ready) return <div className="empty">Loading…</div>;

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          milli<b>more</b>
        </div>
        <div className="nav-label">Platform</div>
        {NAV.map((n) => {
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
      </aside>

      <div className="main">
        <div className="topbar">
          <div className="title">{TITLES[pathname] ?? 'Admin'}</div>
          <div className="row" style={{ gap: 12 }}>
            <div style={{ textAlign: 'right', lineHeight: 1.25 }}>
              <div style={{ fontWeight: 600, fontSize: 13 }}>{user?.name ?? 'Admin'}</div>
              <div className="muted" style={{ fontSize: 12 }}>
                {user?.email}
              </div>
            </div>
            <Avatar name={user?.name ?? 'Admin'} seed={user?.id} size={36} />
            <button
              className="btn ghost sm"
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
