'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

interface Txn {
  id: string;
  kind: 'deposit' | 'withdrawal';
  amount: number;
  currency: string;
  status: string;
  flagged: boolean;
  flagReason: string | null;
  method: string | null;
  createdAt: string;
  user: { id: string; name: string; username: string; email: string | null };
}

const TONE: Record<string, 'amber' | 'green' | 'red' | 'slate'> = {
  pending: 'amber', confirmed: 'green', approved: 'green', paid: 'green', rejected: 'red', failed: 'red',
};
const FILTERS = ['all', 'deposit', 'withdrawal', 'flagged'] as const;

export default function TransactionsPage() {
  const [items, setItems] = useState<Txn[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('all');

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      let q = '';
      if (filter === 'deposit' || filter === 'withdrawal') q = `?kind=${filter}`;
      else if (filter === 'flagged') q = '?flagged=true';
      const p = await apiFetch<{ items: Txn[] }>(`/admin/transactions${q}`);
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

  async function act(t: Txn, action: 'approve' | 'reject' | 'flag' | 'unflag') {
    let body: any = {};
    if (action === 'reject') {
      const reason = window.prompt('Reason for rejection?');
      if (!reason) return;
      body = { reason };
    } else if (action === 'flag') {
      const reason = window.prompt('Flag reason?') ?? 'Flagged for review';
      body = { flagged: true, reason };
    } else if (action === 'unflag') {
      body = { flagged: false };
    }
    const base = t.kind === 'deposit' ? 'deposits' : 'payouts';
    const path =
      action === 'flag' || action === 'unflag'
        ? `/admin/${base}/${t.id}/flag`
        : `/admin/${base}/${t.id}/${action}`;
    setBusy(t.id);
    try {
      await apiFetch(path, { method: 'POST', body: JSON.stringify(body) });
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
        <h1>Transactions</h1>
        <p className="lead">
          All money in and out — deposits and withdrawals. Verify, approve, reject, or flag anything
          that needs a closer look. Every action is written to the audit log.
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
        <div className="panel empty">Loading transactions…</div>
      ) : items.length === 0 ? (
        <div className="panel empty">No transactions.</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead>
              <tr>
                <th>User</th><th>Type</th><th>Amount</th><th>Status</th><th>When</th><th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.map((t) => (
                <tr key={t.id} style={t.flagged ? { background: 'rgba(239,68,68,0.05)' } : undefined}>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={t.user.name} seed={t.user.id} size={32} />
                      <div>
                        <div className="name">{t.user.name} {t.flagged && <Pill tone="red" plain>flagged</Pill>}</div>
                        <div className="cell-sub">@{t.user.username}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ textTransform: 'capitalize' }}>{t.kind}</td>
                  <td className="mono" style={{ fontWeight: 700 }}>${t.amount.toFixed(2)}</td>
                  <td><Pill tone={TONE[t.status] ?? 'slate'}>{t.status}</Pill></td>
                  <td className="muted" style={{ fontSize: 12.5 }}>
                    {new Date(t.createdAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div className="row" style={{ gap: 6, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                      {t.status === 'pending' && (
                        <>
                          <button className="btn sm" disabled={busy === t.id} onClick={() => act(t, 'approve')}>Approve</button>
                          <button className="btn sm ghost" disabled={busy === t.id} onClick={() => act(t, 'reject')}>Reject</button>
                        </>
                      )}
                      {t.flagged ? (
                        <button className="btn sm ghost" disabled={busy === t.id} onClick={() => act(t, 'unflag')}>Unflag</button>
                      ) : (
                        <button className="btn sm ghost" disabled={busy === t.id} onClick={() => act(t, 'flag')}>Flag</button>
                      )}
                    </div>
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
