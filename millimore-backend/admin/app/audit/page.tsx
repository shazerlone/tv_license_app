'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Pill } from '../../components/ui';

interface AuditRow {
  id: string;
  adminId: string;
  action: string;
  targetType: string;
  targetId: string;
  meta: Record<string, unknown> | null;
  createdAt: string;
}

const TONE: Record<string, 'green' | 'red' | 'amber' | 'blue' | 'slate'> = {
  approve: 'green', verify: 'green', reject: 'red', flag: 'red', unflag: 'slate', update: 'blue',
};
const toneFor = (action: string) => {
  const verb = action.split('.')[1] ?? '';
  return TONE[verb] ?? 'slate';
};

export default function AuditPage() {
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [filter, setFilter] = useState('all');

  const FILTERS = ['all', 'deposit', 'payout', 'kyc', 'settings'];

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const q = filter === 'all' ? '' : `?targetType=${filter}`;
      const p = await apiFetch<{ items: AuditRow[] }>(`/admin/audit${q}`);
      setRows(p.items);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <Shell>
      <div className="page-head">
        <h1>Audit log</h1>
        <p className="lead">Every privileged action — approvals, rejections, flags, settings and KYC decisions. Append-only.</p>
      </div>

      <div className="row" style={{ gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
          <button key={f} className={`btn sm ${filter === f ? '' : 'ghost'}`} onClick={() => setFilter(f)} style={{ textTransform: 'capitalize' }}>{f}</button>
        ))}
      </div>

      {err && <div className="error">{err}</div>}

      {loading ? (
        <div className="panel empty">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="panel empty">No audit entries yet.</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead><tr><th>Action</th><th>Target</th><th>Admin</th><th>Details</th><th>When</th></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td><Pill tone={toneFor(r.action)}>{r.action}</Pill></td>
                  <td><span style={{ textTransform: 'capitalize' }}>{r.targetType}</span> <span className="mono cell-sub">{r.targetId}</span></td>
                  <td className="mono cell-sub">{r.adminId}</td>
                  <td className="muted" style={{ fontSize: 12, maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {r.meta ? JSON.stringify(r.meta) : '—'}
                  </td>
                  <td className="muted" style={{ fontSize: 12.5 }}>
                    {new Date(r.createdAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
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
