'use client';

import { useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar } from '../../components/ui';

interface Referrer {
  id: string;
  name: string;
  username: string;
  code: string | null;
  referred: number;
  earned: number;
}

const money = (n: number) => `$${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export default function ReferralsPage() {
  const [rows, setRows] = useState<Referrer[] | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    apiFetch<Referrer[]>('/admin/referrals').then(setRows).catch((e) => setErr(e.message));
  }, []);

  const totalPaid = rows?.reduce((s, r) => s + r.earned, 0) ?? 0;
  const totalReferred = rows?.reduce((s, r) => s + r.referred, 0) ?? 0;

  return (
    <Shell>
      <div className="page-head">
        <h1>Referrals</h1>
        <p className="lead">
          Affiliate / IB leaderboard — who’s bringing in users and what they’ve earned. Rates are set
          in <a href="/settings">Settings</a>.
        </p>
      </div>

      {err && <div className="error">{err}</div>}

      <div className="cards" style={{ marginBottom: 16 }}>
        <div className="card"><div className="stat-tile"><div className="stat">{rows ? rows.length : '—'}</div><div className="stat-label">Active referrers</div></div></div>
        <div className="card"><div className="stat-tile"><div className="stat">{rows ? totalReferred : '—'}</div><div className="stat-label">People referred</div></div></div>
        <div className="card"><div className="stat-tile"><div className="stat">{rows ? money(totalPaid) : '—'}</div><div className="stat-label">Affiliate paid out</div></div></div>
      </div>

      {!rows ? (
        <div className="panel empty">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="panel empty">No affiliate earnings yet.</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead><tr><th>#</th><th>Referrer</th><th>Code</th><th>Referred</th><th>Earned</th></tr></thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={r.id}>
                  <td className="muted">{i + 1}</td>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={r.name} seed={r.id} size={32} />
                      <div><div className="name">{r.name}</div><div className="cell-sub">@{r.username}</div></div>
                    </div>
                  </td>
                  <td className="mono">{r.code || '—'}</td>
                  <td className="mono">{r.referred}</td>
                  <td className="mono" style={{ fontWeight: 700, color: 'var(--green)' }}>{money(r.earned)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Shell>
  );
}
