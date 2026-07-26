'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Shell from '../components/Shell';
import { apiFetch, AdminUser } from '../lib/api';

interface Page {
  items: AdminUser[];
  nextCursor: string | null;
}

export default function OverviewPage() {
  const [users, setUsers] = useState<AdminUser[] | null>(null);
  const [pending, setPending] = useState<number | null>(null);

  useEffect(() => {
    // Sample the first page of users for quick counts. A dedicated
    // /admin/metrics endpoint arrives in milestone 6.
    apiFetch<Page>('/admin/users?limit=100').then((p) => setUsers(p.items)).catch(() => setUsers([]));
    apiFetch<any[]>('/admin/creators/pending').then((r) => setPending(r.length)).catch(() => {});
  }, []);

  const total = users?.length ?? null;
  const creators = users?.filter((u) => u.role === 'creator').length ?? null;
  const approved =
    users?.filter((u) => u.creatorStatus === 'approved').length ?? null;
  const banned = users?.filter((u) => u.banned).length ?? null;

  const stat = (label: string, value: number | null) => (
    <div className="card">
      <div className="stat">{value ?? '—'}</div>
      <div className="stat-label">{label}</div>
    </div>
  );

  return (
    <Shell>
      <h1>Overview</h1>
      <p className="subtle">
        A snapshot of the platform. Full metrics (DAU/MAU, GMV, live streams) land with the
        milestone&nbsp;6 <code>/admin/metrics</code> endpoint.
      </p>
      <div className="cards" style={{ marginTop: 18 }}>
        {stat('Users (sampled)', total)}
        {stat('Creators', creators)}
        {stat('Approved creators', approved)}
        {stat('Banned', banned)}
        <Link href="/creators" className="card" style={{ display: 'block' }}>
          <div className="stat" style={{ color: pending ? 'var(--amber)' : undefined }}>
            {pending ?? '—'}
          </div>
          <div className="stat-label">Pending approvals →</div>
        </Link>
      </div>
    </Shell>
  );
}
