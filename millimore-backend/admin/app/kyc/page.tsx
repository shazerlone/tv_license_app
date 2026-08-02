'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

interface KycUser {
  id: string;
  name: string;
  username: string;
  email: string | null;
  kycStatus: 'none' | 'pending' | 'verified' | 'rejected';
  kycProvider: string | null;
  residenceCountry: string | null;
  createdAt: string;
}

const TONE: Record<string, 'amber' | 'green' | 'red' | 'slate'> = {
  pending: 'amber', verified: 'green', rejected: 'red', none: 'slate',
};
const FILTERS = ['pending', 'verified', 'rejected', 'all'] as const;

export default function KycPage() {
  const [items, setItems] = useState<KycUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('pending');

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const q = filter === 'all' ? '' : `?status=${filter}`;
      const p = await apiFetch<{ items: KycUser[] }>(`/admin/kyc${q}`);
      setItems(p.items);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(u: KycUser, action: 'verify' | 'reject') {
    let body: any = {};
    if (action === 'reject') {
      const reason = window.prompt(`Reject ${u.name}'s verification — reason?`);
      if (!reason) return;
      body = { reason };
    }
    setBusy(u.id);
    try {
      await apiFetch(`/admin/kyc/${u.id}/${action}`, { method: 'POST', body: JSON.stringify(body) });
      await load();
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <Shell>
      <div className="page-head">
        <h1>KYC</h1>
        <p className="lead">
          Identity verification. When Sumsub is connected, statuses update automatically via webhook;
          you can also verify or reject manually here.
        </p>
      </div>

      <div className="row" style={{ gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
          <button key={f} className={`btn sm ${filter === f ? '' : 'ghost'}`} onClick={() => setFilter(f)} style={{ textTransform: 'capitalize' }}>
            {f}
          </button>
        ))}
      </div>

      {err && <div className="error">{err}</div>}

      {loading ? (
        <div className="panel empty">Loading…</div>
      ) : items.length === 0 ? (
        <div className="panel empty">No {filter === 'all' ? '' : filter} submissions.</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead>
              <tr><th>User</th><th>Country</th><th>Provider</th><th>Status</th><th style={{ textAlign: 'right' }}>Actions</th></tr>
            </thead>
            <tbody>
              {items.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={u.name} seed={u.id} size={32} />
                      <div><div className="name">{u.name}</div><div className="cell-sub">@{u.username}</div></div>
                    </div>
                  </td>
                  <td>{u.residenceCountry || <span className="muted">—</span>}</td>
                  <td>{u.kycProvider || <span className="muted">—</span>}</td>
                  <td><Pill tone={TONE[u.kycStatus] ?? 'slate'}>{u.kycStatus}</Pill></td>
                  <td style={{ textAlign: 'right' }}>
                    {u.kycStatus !== 'verified' ? (
                      <div className="row" style={{ gap: 6, justifyContent: 'flex-end' }}>
                        <button className="btn sm" disabled={busy === u.id} onClick={() => decide(u, 'verify')}>Verify</button>
                        <button className="btn sm ghost" disabled={busy === u.id} onClick={() => decide(u, 'reject')}>Reject</button>
                      </div>
                    ) : (
                      <span className="muted" style={{ fontSize: 12.5 }}>—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Shell>
  );
}
