'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch, AdminUser } from '../../lib/api';
import { Avatar, Icons } from '../../components/ui';

interface Page {
  items: AdminUser[];
  nextCursor: string | null;
}

const ROLES = ['follower', 'creator', 'admin'] as const;
const STATUSES = ['none', 'pending', 'approved', 'rejected', 'suspended'] as const;

export default function UsersPage() {
  const [rows, setRows] = useState<AdminUser[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [role, setRole] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const buildQuery = useCallback(
    (cur?: string | null) => {
      const p = new URLSearchParams({ limit: '20' });
      if (q) p.set('q', q);
      if (role) p.set('role', role);
      if (cur) p.set('cursor', cur);
      return p.toString();
    },
    [q, role],
  );

  const load = useCallback(
    async (reset: boolean) => {
      setLoading(true);
      setError(null);
      try {
        const cur = reset ? null : cursor;
        const page = await apiFetch<Page>(`/admin/users?${buildQuery(cur)}`);
        setRows((prev) => (reset ? page.items : [...prev, ...page.items]));
        setCursor(page.nextCursor);
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    },
    [buildQuery, cursor],
  );

  useEffect(() => {
    const t = setTimeout(() => load(true), 250);
    return () => clearTimeout(t);
  }, [q, role]);

  async function patch(id: string, body: Record<string, unknown>) {
    try {
      const updated = await apiFetch<AdminUser>(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      });
      setRows((prev) => prev.map((u) => (u.id === id ? updated : u)));
    } catch (err: any) {
      setError(err.message);
    }
  }

  return (
    <Shell>
      <div className="page-head">
        <h1>Users</h1>
        <p className="lead">Manage roles, creator status, and access across the platform.</p>
      </div>

      <div className="toolbar">
        <div className="search-wrap search">
          <Icons.search />
          <input
            placeholder="Search name, username or email"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            style={{ width: '100%' }}
          />
        </div>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">All roles</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r[0].toUpperCase() + r.slice(1)}
            </option>
          ))}
        </select>
        <div className="spacer" />
        <button className="btn ghost" onClick={() => load(true)} disabled={loading}>
          Refresh
        </button>
      </div>

      {error && <div className="error">{error}</div>}

      <div className="panel">
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Contact</th>
              <th>Role</th>
              <th>Creator status</th>
              <th style={{ textAlign: 'right' }}>Access</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((u) => (
              <tr key={u.id}>
                <td>
                  <div className="user-cell">
                    <Avatar name={u.name} seed={u.id} />
                    <div>
                      <div className="cell-name">{u.name}</div>
                      <div className="cell-sub">@{u.username}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <div>{u.email || <span className="muted">—</span>}</div>
                  <div className="cell-sub mono">{u.phone || ''}</div>
                </td>
                <td>
                  <select
                    className="select-inline"
                    value={u.role}
                    onChange={(e) => patch(u.id, { role: e.target.value })}
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {r}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <select
                    className="select-inline"
                    value={u.creatorStatus}
                    onChange={(e) => patch(u.id, { creatorStatus: e.target.value })}
                  >
                    {STATUSES.map((s) => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </td>
                <td style={{ textAlign: 'right' }}>
                  {u.banned ? (
                    <div className="row" style={{ justifyContent: 'flex-end' }}>
                      <span className="pill red">banned</span>
                      <button className="btn ghost sm" onClick={() => patch(u.id, { banned: false })}>
                        Unban
                      </button>
                    </div>
                  ) : (
                    <button className="btn danger sm" onClick={() => patch(u.id, { banned: true })}>
                      Ban
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {rows.length === 0 && !loading && (
              <tr>
                <td colSpan={5} className="empty">
                  No users match your filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="pagination">
        {cursor ? (
          <button className="btn ghost" onClick={() => load(false)} disabled={loading}>
            {loading ? 'Loading…' : 'Load more'}
          </button>
        ) : (
          rows.length > 0 && <span className="muted">End of list · {rows.length} shown</span>
        )}
      </div>
    </Shell>
  );
}
