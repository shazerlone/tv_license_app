'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Shell from '../components/Shell';
import { apiFetch, AdminUser } from '../lib/api';
import { Icons } from '../components/ui';

interface Page {
  items: AdminUser[];
  nextCursor: string | null;
}

export default function OverviewPage() {
  const [users, setUsers] = useState<AdminUser[] | null>(null);
  const [pending, setPending] = useState<number | null>(null);

  useEffect(() => {
    apiFetch<Page>('/admin/users?limit=100').then((p) => setUsers(p.items)).catch(() => setUsers([]));
    apiFetch<any[]>('/admin/creators/pending').then((r) => setPending(r.length)).catch(() => {});
  }, []);

  const total = users?.length ?? null;
  const creators = users?.filter((u) => u.role === 'creator').length ?? null;
  const approved = users?.filter((u) => u.creatorStatus === 'approved').length ?? null;
  const banned = users?.filter((u) => u.banned).length ?? null;

  const Tile = ({
    value,
    label,
    tone = 'blue',
    icon,
    href,
  }: {
    value: number | null;
    label: string;
    tone?: string;
    icon: () => JSX.Element;
    href?: string;
  }) => {
    const Icon = icon;
    const inner = (
      <div className="stat-tile">
        <div className="stat-top">
          <div className={`stat-ico ${tone}`}>
            <Icon />
          </div>
          {href && <span className="muted" style={{ fontSize: 18, lineHeight: 1 }}>›</span>}
        </div>
        <div className="stat">{value ?? '—'}</div>
        <div className="stat-label">{label}</div>
      </div>
    );
    return href ? (
      <Link href={href} className="card stat-tile" style={{ padding: 0 }}>
        {inner}
      </Link>
    ) : (
      <div className="card">{inner}</div>
    );
  };

  return (
    <Shell>
      <div className="page-head">
        <h1>Overview</h1>
        <p className="lead">
          A snapshot of the platform. Full engagement metrics — DAU/MAU, GMV, live streams — arrive
          with the milestone&nbsp;6 <code>/admin/metrics</code> endpoint.
        </p>
      </div>

      <div className="cards">
        <Tile value={total} label="Total users" tone="blue" icon={Icons.users} />
        <Tile value={creators} label="Creators" tone="amber" icon={Icons.spark} />
        <Tile value={approved} label="Approved creators" tone="green" icon={Icons.approved} />
        <Tile value={banned} label="Banned" tone="slate" icon={Icons.users} />
        <Tile
          value={pending}
          label="Pending approvals"
          tone="amber"
          icon={Icons.queue}
          href="/creators"
        />
      </div>
    </Shell>
  );
}
