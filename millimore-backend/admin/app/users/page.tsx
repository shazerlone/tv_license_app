'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch, AdminUser } from '../../lib/api';
import { Avatar, Icons, RolePill, StatusPill, Pill } from '../../components/ui';

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
  const [detail, setDetail] = useState<AdminUser | null>(null);

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

  const patch = useCallback(async (id: string, body: Record<string, unknown>) => {
    try {
      const updated = await apiFetch<AdminUser>(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(body),
      });
      setRows((prev) => prev.map((u) => (u.id === id ? updated : u)));
      setDetail((d) => (d && d.id === id ? updated : d));
    } catch (err: any) {
      setError(err.message);
    }
  }, []);

  const roleSelect = (u: AdminUser) => (
    <select className="select-inline" value={u.role} onChange={(e) => patch(u.id, { role: e.target.value })}>
      {ROLES.map((r) => (
        <option key={r} value={r}>{r}</option>
      ))}
    </select>
  );
  const statusSelect = (u: AdminUser) => (
    <select className="select-inline" value={u.creatorStatus} onChange={(e) => patch(u.id, { creatorStatus: e.target.value })}>
      {STATUSES.map((s) => (
        <option key={s} value={s}>{s}</option>
      ))}
    </select>
  );
  const banBtn = (u: AdminUser) =>
    u.banned ? (
      <button className="btn ghost sm" onClick={() => patch(u.id, { banned: false })}>Unban</button>
    ) : (
      <button className="btn danger sm" onClick={() => patch(u.id, { banned: true })}>Ban</button>
    );

  return (
    <Shell>
      <div className="page-head">
        <h1>Users</h1>
        <p className="lead">Manage roles, creator status, and access.</p>
      </div>

      <div className="toolbar">
        <div className="search-wrap search">
          <Icons.search />
          <input placeholder="Search name, username or email" value={q} onChange={(e) => setQ(e.target.value)} style={{ width: '100%' }} />
        </div>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">All roles</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>{r[0].toUpperCase() + r.slice(1)}</option>
          ))}
        </select>
        <div className="spacer" />
        <button className="btn ghost" onClick={() => load(true)} disabled={loading}>Refresh</button>
      </div>

      {error && <div className="error">{error}</div>}

      {/* Desktop table */}
      <div className="panel only-desktop">
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
                  <div className="user-cell link-name" onClick={() => setDetail(u)}>
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
                <td>{roleSelect(u)}</td>
                <td>{statusSelect(u)}</td>
                <td style={{ textAlign: 'right' }}>
                  <div className="row" style={{ justifyContent: 'flex-end' }}>
                    {u.banned && <Pill tone="red">banned</Pill>}
                    {banBtn(u)}
                  </div>
                </td>
              </tr>
            ))}
            {rows.length === 0 && !loading && (
              <tr><td colSpan={5} className="empty">No users match your filters.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Mobile cards */}
      <div className="only-mobile">
        {rows.map((u) => (
          <div key={u.id} className="user-card">
            <div className="top">
              <Avatar name={u.name} seed={u.id} />
              <div className="grow link-name" onClick={() => setDetail(u)}>
                <div className="cell-name">{u.name}</div>
                <div className="cell-sub">@{u.username}</div>
              </div>
              {u.banned ? <Pill tone="red">banned</Pill> : <RolePill role={u.role} />}
            </div>
            <div className="contact">
              {u.email || '—'}{u.phone ? ` · ${u.phone}` : ''}
            </div>
            <div className="controls">
              {roleSelect(u)}
              {statusSelect(u)}
            </div>
            <div className="actions">
              <button className="btn ghost sm" onClick={() => setDetail(u)}>Details</button>
              {banBtn(u)}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <div className="empty">No users match your filters.</div>}
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

      {detail && (
        <UserDetail
          user={detail}
          onClose={() => setDetail(null)}
          roleSelect={roleSelect}
          statusSelect={statusSelect}
          banBtn={banBtn}
        />
      )}
    </Shell>
  );
}

function UserDetail({
  user,
  onClose,
  roleSelect,
  statusSelect,
  banBtn,
}: {
  user: AdminUser;
  onClose: () => void;
  roleSelect: (u: AdminUser) => JSX.Element;
  statusSelect: (u: AdminUser) => JSX.Element;
  banBtn: (u: AdminUser) => JSX.Element;
}) {
  const kv = (k: string, v: React.ReactNode) => (
    <>
      <div className="k">{k}</div>
      <div className="v">{v || <span className="muted">—</span>}</div>
    </>
  );
  return (
    <>
      <div className="backdrop" style={{ zIndex: 65 }} onClick={onClose} />
      <aside className="drawer open">
        <div className="drawer-inner">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <div className="row" style={{ gap: 11 }}>
              <Avatar name={user.name} seed={user.id} size={46} />
              <div>
                <div style={{ fontWeight: 800, fontSize: 16, letterSpacing: '-0.02em' }}>{user.name}</div>
                <div className="cell-sub">@{user.username}</div>
              </div>
            </div>
            <button className="drawer-close" onClick={onClose} aria-label="Close">×</button>
          </div>

          <div className="row" style={{ gap: 6, marginTop: 12 }}>
            <RolePill role={user.role} />
            <StatusPill status={user.creatorStatus} />
            {user.banned && <Pill tone="red">banned</Pill>}
          </div>

          <div className="detail-kv">
            {kv('Email', user.email)}
            {kv('Phone', <span className="mono">{user.phone || ''}</span>)}
            {kv('Residence', user.residenceCountry)}
            {kv('Market', user.market)}
            {kv('Platform', user.platform)}
            {kv('Joined', new Date(user.createdAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' }))}
            {kv('User ID', <span className="mono">{user.id}</span>)}
          </div>

          <div className="section-title">Manage</div>
          <div className="controls" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            {roleSelect(user)}
            {statusSelect(user)}
          </div>
          <div style={{ marginTop: 10 }}>{banBtn(user)}</div>
        </div>
      </aside>
    </>
  );
}
