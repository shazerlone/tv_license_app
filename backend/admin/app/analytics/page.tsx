'use client';

import { useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { LineChart, BarsChart, Pt } from '../../components/Charts';
import { Avatar } from '../../components/ui';

interface Analytics {
  range: number;
  series: { date: string; signups: number; deposits: number; withdrawals: number; revenue: number }[];
  totals: {
    users: number; newUsers30d: number; creators: number; kycVerified: number;
    depositsTotal: number; withdrawalsTotal: number; revenueTotal: number;
    copyVolume: number; walletLiabilities: number; activeCopies: number;
  };
  topTraders: { id: string; name: string; username: string; photoUrl: string | null; copiers: number; aum: number; returnPercent: number }[];
}

const money = (n: number) =>
  n >= 1000 ? `$${(n / 1000).toFixed(n >= 100000 ? 0 : 1)}k` : `$${n.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;

export default function AnalyticsPage() {
  const [a, setA] = useState<Analytics | null>(null);
  const [days, setDays] = useState(30);
  const [err, setErr] = useState(false);

  useEffect(() => {
    setA(null);
    apiFetch<Analytics>(`/admin/analytics?days=${days}`).then(setA).catch(() => setErr(true));
  }, [days]);

  const pt = (k: 'signups' | 'deposits' | 'withdrawals' | 'revenue'): Pt[] =>
    (a?.series ?? []).map((s) => ({ date: s.date, value: s[k] }));

  const Kpi = ({ label, value, sub }: { label: string; value: string; sub?: string }) => (
    <div className="card">
      <div className="stat-tile">
        <div className="stat">{value}</div>
        <div className="stat-label">{label}</div>
        {sub && <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{sub}</div>}
      </div>
    </div>
  );

  const Panel = ({ title, legend, children }: { title: string; legend?: React.ReactNode; children: React.ReactNode }) => (
    <div className="card" style={{ marginBottom: 16 }}>
      <div className="row" style={{ justifyContent: 'space-between', marginBottom: 10, alignItems: 'center' }}>
        <div style={{ fontWeight: 700 }}>{title}</div>
        {legend}
      </div>
      {children}
    </div>
  );

  const Dot = ({ c, t }: { c: string; t: string }) => (
    <span className="row" style={{ gap: 6, fontSize: 12, color: 'var(--text-secondary)' }}>
      <span style={{ width: 9, height: 9, borderRadius: 3, background: c, display: 'inline-block' }} />{t}
    </span>
  );

  return (
    <Shell>
      <div className="page-head">
        <div className="row" style={{ justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, flexWrap: 'wrap' }}>
          <div>
            <h1>Analytics</h1>
            <p className="lead">Growth, money flow and revenue over time — live from your data.</p>
          </div>
          <div className="row" style={{ gap: 6 }}>
            {[7, 30, 90].map((d) => (
              <button key={d} className={`btn sm ${days === d ? '' : 'ghost'}`} onClick={() => setDays(d)}>{d}d</button>
            ))}
          </div>
        </div>
      </div>

      {err && <div className="error">Couldn’t load analytics. Check you’re signed in as an admin.</div>}

      <div className="cards" style={{ marginBottom: 16 }}>
        <Kpi label="Total users" value={a ? a.totals.users.toLocaleString() : '—'} sub={a ? `+${a.totals.newUsers30d} in 30d` : undefined} />
        <Kpi label="Deposits (total)" value={a ? money(a.totals.depositsTotal) : '—'} />
        <Kpi label="Platform revenue" value={a ? money(a.totals.revenueTotal) : '—'} />
        <Kpi label="Active copy volume" value={a ? money(a.totals.copyVolume) : '—'} sub={a ? `${a.totals.activeCopies} active copies` : undefined} />
        <Kpi label="KYC verified" value={a ? a.totals.kycVerified.toLocaleString() : '—'} />
      </div>

      <Panel title="New signups">
        {a ? <LineChart points={pt('signups')} color="var(--primary)" /> : <div className="empty">Loading…</div>}
      </Panel>

      <Panel title="Deposits vs withdrawals" legend={<div className="row" style={{ gap: 14 }}><Dot c="var(--green)" t="Deposits" /><Dot c="var(--red)" t="Withdrawals" /></div>}>
        {a ? <BarsChart points={pt('deposits')} seriesB={pt('withdrawals')} /> : <div className="empty">Loading…</div>}
      </Panel>

      <Panel title="Platform revenue">
        {a ? <LineChart points={pt('revenue')} color="var(--amber, #f59e0b)" money /> : <div className="empty">Loading…</div>}
      </Panel>

      <div className="card">
        <div style={{ fontWeight: 700, marginBottom: 12 }}>Top traders</div>
        {a && a.topTraders.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table className="tbl">
              <thead><tr><th>Trader</th><th>Copiers</th><th>AUM</th><th>Return</th></tr></thead>
              <tbody>
                {a.topTraders.map((t) => (
                  <tr key={t.id}>
                    <td>
                      <div className="row" style={{ gap: 10 }}>
                        <Avatar name={t.name} seed={t.id} size={32} />
                        <div><div className="name">{t.name}</div><div className="cell-sub">@{t.username}</div></div>
                      </div>
                    </td>
                    <td className="mono">{t.copiers.toLocaleString()}</td>
                    <td className="mono">{money(t.aum)}</td>
                    <td className="mono" style={{ color: t.returnPercent >= 0 ? 'var(--green)' : 'var(--red)' }}>
                      {t.returnPercent >= 0 ? '+' : ''}{t.returnPercent}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="empty">No traders yet.</div>
        )}
      </div>
    </Shell>
  );
}
