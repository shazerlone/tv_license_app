'use client';

import { ReactNode, useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { apiFetch, getStoredUser } from '../lib/api';
import { isAuthed, logout } from '../lib/auth';

const NAV = [
  { href: '/', label: 'Overview' },
  { href: '/users', label: 'Users' },
  { href: '/creators', label: 'Creator queue' },
];

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
    // Pending-queue badge.
    apiFetch<any[]>('/admin/creators/pending')
      .then((rows) => setPending(rows.length))
      .catch(() => setPending(null));
  }, [router]);

  if (!ready) return <div className="empty">Loading…</div>;

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          Milli<span>more</span>
        </div>
        {NAV.map((n) => {
          const active = n.href === '/' ? pathname === '/' : pathname.startsWith(n.href);
          return (
            <Link key={n.href} href={n.href} className={`navlink ${active ? 'active' : ''}`}>
              <span>{n.label}</span>
              {n.href === '/creators' && pending ? (
                <span className="badge-count">{pending}</span>
              ) : null}
            </Link>
          );
        })}
      </aside>
      <div className="main">
        <div className="topbar">
          <div className="subtle">Admin dashboard</div>
          <div className="row">
            <span className="subtle">{user?.name ?? user?.email}</span>
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
