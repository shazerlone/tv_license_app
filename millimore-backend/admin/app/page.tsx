'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Shell from '../components/Shell';
import { apiFetch, AdminMetrics } from '../lib/api';
import { Icons } from '../components/ui';

const money = (n: number) =>
  n >= 1000
    ? `$${(n / 1000).toFixed(n >= 100000 ? 0 : 1)}k`
    : `$${n.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;

const num = (n: number) => n.toLocaleString();

export default function OverviewPage() {
  const [m, setM] = useState<AdminMetrics | null>(null);
  const [err, setErr] = useState(false);

  useEffect(() => {
    apiFetch<AdminMetrics>('/admin/metrics').then(setM).catch(() => setErr(true));
  }, []);

  const Tile = ({
    value,
    label,
    tone = 'blue',
    icon,
    href,
    hint,
  }: {
    value: string | number | null;
    label: string;
    tone?: string;
    icon: () => JSX.Element;
    href?: string;
    hint?: string;
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
        {hint && <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{hint}</div>}
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
          Live platform metrics from <code>/admin/metrics</code> — engagement, trading volume,
          deposits and revenue, updated on every load.
        </p>
      </div>

      {err && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="muted">Couldn’t load metrics. Check you’re signed in as an admin.</div>
        </div>
      )}

      <div className="nav-label" style={{ marginBottom: 8 }}>Engagement</div>
      <div className="cards">
        <Tile value={m ? num(m.totalUsers) : null} label="Total users" tone="blue" icon={Icons.users} />
        <Tile value={m ? num(m.dau) : null} label="Active today (DAU)" tone="green" icon={Icons.spark} />
        <Tile value={m ? num(m.mau) : null} label="Active this month (MAU)" tone="blue" icon={Icons.spark} />
        <Tile value={m ? num(m.creators) : null} label="Approved creators" tone="amber" icon={Icons.approved} />
        <Tile value={m ? num(m.liveNow) : null} label="Live now" tone="green" icon={Icons.spark} />
        <Tile value={m ? num(m.streamsToday) : null} label="Streams today" tone="slate" icon={Icons.queue} />
      </div>

      <div className="nav-label" style={{ margin: '20px 0 8px' }}>Money</div>
      <div className="cards">
        <Tile value={m ? money(m.depositsTotal) : null} label="Deposits (total)" tone="green" icon={Icons.spark} />
        <Tile value={m ? money(m.copyVolume) : null} label="Active copy volume" tone="blue" icon={Icons.spark} hint={m ? `GMV ${money(m.gmv)} all-time` : undefined} />
        <Tile value={m ? money(m.walletLiabilities) : null} label="Wallet balances" tone="slate" icon={Icons.users} hint="User liabilities" />
        <Tile value={m ? money(m.platformRevenue) : null} label="Platform revenue" tone="amber" icon={Icons.approved} hint="Fee share booked" />
        <Tile
          value={m ? num(m.pendingPayouts) : null}
          label="Pending payouts"
          tone="amber"
          icon={Icons.queue}
          href="/payouts"
          hint={m ? money(m.pendingPayoutAmount) : undefined}
        />
      </div>
    </Shell>
  );
}
