'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch, AdminPayout } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

interface Page {
  items: AdminPayout[];
  nextCursor: string | null;
}

const STATUS_TONE: Record<string, 'amber' | 'green' | 'red' | 'slate'> = {
  pending: 'amber',
  approved: 'green',
  paid: 'green',
  rejected: 'red',
};

const FILTERS = ['pending', 'approved', 'rejected', 'all'] as const;

export default function PayoutsPage() {
  const [items, setItems] = useState<AdminPayout[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [workingId, setWorkingId] = useState<string | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('pending');

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const q = filter === 'all' ? '' : `?status=${filter}`;
      const p = await apiFetch<Page>(`/admin/payouts${q}`);
      setItems(p.items);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(p: AdminPayout, action: 'approve' | 'reject') {
    let body: Record<string, string> = {};
    if (action === 'reject') {
      const reason = window.prompt(`Reject ${p.requester.name}'s $${p.amount} withdrawal — reason?`);
      if (!reason) return;
      body = { reason };
    } else {
      if (!window.confirm(`Approve ${p.requester.name}'s $${p.amount.toFixed(2)} withdrawal?`)) return;
    }
    setWorkingId(p.id);
    setError(null);
    try {
      await apiFetch(`/admin/payouts/${p.id}/${action}`, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      await load();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setWorkingId(null);
    }
  }

  return (
    <Shell>
      <div className="page-head">
        <h1>Payouts</h1>
        <p className="lead">
          Creator & user withdrawal requests. Requesting holds the funds; approving confirms the
          transfer, rejecting returns the money to the wallet.
        </p>
      </div>

      <div className="row" style={{ gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
          <button
            key={f}
            className={`btn sm ${filter === f ? '' : 'ghost'}`}
            onClick={() => setFilter(f)}
            style={{ textTransform: 'capitalize' }}
          >
            {f}
          </button>
        ))}
      </div>

      {error && <div className="error">{error}</div>}

      {loading ? (
        <div className="panel empty">Loading payouts…</div>
      ) : items.length === 0 ? (
        <div className="panel empty">
          <div className="big">✓</div>
          No {filter === 'all' ? '' : filter} payout requests.
        </div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead>
              <tr>
                <th>Requester</th>
                <th>Amount</th>
                <th>Method</th>
                <th>Status</th>
                <th>Requested</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.map((p) => (
                <tr key={p.id}>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={p.requester.name} seed={p.requester.id} size={34} />
                      <div>
                        <div className="name">{p.requester.name}</div>
                        <div className="cell-sub">@{p.requester.username}</div>
                      </div>
                    </div>
                  </td>
                  <td className="mono" style={{ fontWeight: 700 }}>
                    ${p.amount.toFixed(2)}
                  </td>
                  <td>{p.method || <span className="muted">—</span>}</td>
                  <td>
                    <Pill tone={STATUS_TONE[p.status] ?? 'slate'}>{p.status}</Pill>
                  </td>
                  <td className="muted" style={{ fontSize: 12.5 }}>
                    {new Date(p.createdAt).toLocaleDateString(undefined, {
                      month: 'short',
                      day: 'numeric',
                      year: 'numeric',
                    })}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    {p.status === 'pending' ? (
                      <div className="row" style={{ gap: 6, justifyContent: 'flex-end' }}>
                        <button
                          className="btn sm"
                          disabled={workingId === p.id}
                          onClick={() => decide(p, 'approve')}
                        >
                          Approve
                        </button>
                        <button
                          className="btn sm ghost"
                          disabled={workingId === p.id}
                          onClick={() => decide(p, 'reject')}
                        >
                          Reject
                        </button>
                      </div>
                    ) : (
                      <span className="muted" style={{ fontSize: 12.5 }}>
                        {p.reason || '—'}
                      </span>
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
