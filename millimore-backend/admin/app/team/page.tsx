'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

interface Admin {
  id: string; name: string; username: string; email: string | null;
  adminRole: string; createdAt: string;
}

const ROLES = ['superadmin', 'finance', 'compliance', 'support', 'analyst'];
const ROLE_DESC: Record<string, string> = {
  superadmin: 'Full access to everything',
  finance: 'Deposits, withdrawals, balances, analytics',
  compliance: 'KYC, audit, withdrawal review',
  support: 'Tickets & announcements',
  analyst: 'Read-only analytics & reports',
};
const TONE: Record<string, 'blue' | 'green' | 'amber' | 'slate'> = {
  superadmin: 'blue', finance: 'green', compliance: 'amber', support: 'slate', analyst: 'slate',
};

export default function TeamPage() {
  const [rows, setRows] = useState<Admin[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(async () => {
    setErr(null);
    try { setRows(await apiFetch<Admin[]>('/admin/team')); }
    catch (e: any) { setErr(e.message); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const setRole = async (a: Admin, adminRole: string) => {
    setBusy(a.id);
    try { await apiFetch(`/admin/team/${a.id}/role`, { method: 'POST', body: JSON.stringify({ adminRole }) }); await load(); }
    catch (e: any) { setErr(e.message); } finally { setBusy(null); }
  };

  return (
    <Shell>
      <div className="page-head">
        <h1>Team</h1>
        <p className="lead">Back-office staff and their access. Assign a role to scope what each admin can see and do.</p>
      </div>

      {err && <div className="error">{err}</div>}

      <div className="card" style={{ marginBottom: 16 }}>
        <div className="nav-label" style={{ marginBottom: 8 }}>Roles</div>
        <div style={{ display: 'grid', gap: 6 }}>
          {ROLES.map((r) => (
            <div key={r} className="row" style={{ gap: 8, fontSize: 13 }}>
              <Pill tone={TONE[r]}>{r}</Pill>
              <span className="muted">{ROLE_DESC[r]}</span>
            </div>
          ))}
        </div>
      </div>

      {!rows ? (
        <div className="panel empty">Loading…</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead><tr><th>Admin</th><th>Email</th><th>Role</th><th style={{ textAlign: 'right' }}>Assign</th></tr></thead>
            <tbody>
              {rows.map((a) => (
                <tr key={a.id}>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={a.name} seed={a.id} size={32} />
                      <div><div className="name">{a.name}</div><div className="cell-sub">@{a.username}</div></div>
                    </div>
                  </td>
                  <td>{a.email || <span className="muted">—</span>}</td>
                  <td><Pill tone={TONE[a.adminRole] ?? 'slate'}>{a.adminRole}</Pill></td>
                  <td style={{ textAlign: 'right' }}>
                    <select
                      className="select-inline"
                      value={a.adminRole}
                      disabled={busy === a.id}
                      onChange={(e) => setRole(a, e.target.value)}
                    >
                      {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
                    </select>
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
