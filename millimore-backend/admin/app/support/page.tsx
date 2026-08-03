'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

interface Msg { id: string; authorRole: string; body: string; internal: boolean; createdAt: string }
interface Ticket {
  id: string; subject: string; category: string; priority: string; status: string;
  createdAt: string; lastMessageAt: string;
  user?: { id: string; name: string; username: string; email: string | null };
  messages?: Msg[];
}

const STATUS_TONE: Record<string, 'amber' | 'green' | 'red' | 'blue' | 'slate'> = {
  open: 'blue', pending: 'amber', resolved: 'green', closed: 'slate',
};
const PRIO_TONE: Record<string, 'red' | 'amber' | 'slate'> = { urgent: 'red', high: 'red', normal: 'slate', low: 'slate' };
const FILTERS = ['open', 'pending', 'resolved', 'closed', 'all'] as const;
const STATUSES = ['open', 'pending', 'resolved', 'closed'];
const PRIORITIES = ['low', 'normal', 'high', 'urgent'];

export default function SupportPage() {
  const [rows, setRows] = useState<Ticket[]>([]);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('open');
  const [sel, setSel] = useState<Ticket | null>(null);
  const [reply, setReply] = useState('');
  const [internal, setInternal] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const q = filter === 'all' ? '' : `?status=${filter}`;
      setRows(await apiFetch<Ticket[]>(`/admin/support/tickets${q}`));
    } catch (e: any) { setErr(e.message); }
  }, [filter]);

  useEffect(() => { load(); }, [load]);

  const open = async (t: Ticket) => {
    setReply(''); setInternal(false);
    try { setSel(await apiFetch<Ticket>(`/admin/support/tickets/${t.id}`)); } catch (e: any) { setErr(e.message); }
  };

  const send = async () => {
    if (!sel || !reply.trim()) return;
    setBusy(true);
    try {
      const updated = await apiFetch<Ticket>(`/admin/support/tickets/${sel.id}/messages`, {
        method: 'POST', body: JSON.stringify({ body: reply.trim(), internal }),
      });
      setSel(updated); setReply(''); setInternal(false); load();
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  };

  const patch = async (body: Record<string, string>) => {
    if (!sel) return;
    try {
      const updated = await apiFetch<Ticket>(`/admin/support/tickets/${sel.id}`, { method: 'PATCH', body: JSON.stringify(body) });
      setSel(updated); load();
    } catch (e: any) { setErr(e.message); }
  };

  return (
    <Shell>
      <div className="page-head">
        <h1>Support</h1>
        <p className="lead">Customer tickets — reply, add internal notes, and manage status & priority.</p>
      </div>

      <div className="row" style={{ gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
          <button key={f} className={`btn sm ${filter === f ? '' : 'ghost'}`} onClick={() => setFilter(f)} style={{ textTransform: 'capitalize' }}>{f}</button>
        ))}
      </div>
      {err && <div className="error">{err}</div>}

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 340px) 1fr', gap: 16, alignItems: 'start' }} className="support-grid">
        {/* Ticket list */}
        <div className="panel" style={{ padding: 0, overflow: 'hidden' }}>
          {rows.length === 0 ? (
            <div className="empty">No {filter === 'all' ? '' : filter} tickets.</div>
          ) : rows.map((t) => (
            <div
              key={t.id}
              onClick={() => open(t)}
              style={{
                padding: '12px 14px', borderBottom: '1px solid var(--border)', cursor: 'pointer',
                background: sel?.id === t.id ? 'var(--surface, #f8fafc)' : undefined,
              }}
            >
              <div className="row" style={{ justifyContent: 'space-between', gap: 8 }}>
                <div style={{ fontWeight: 600, fontSize: 13.5 }}>{t.subject}</div>
                <Pill tone={STATUS_TONE[t.status] ?? 'slate'}>{t.status}</Pill>
              </div>
              <div className="cell-sub" style={{ marginTop: 3 }}>
                @{t.user?.username ?? '—'} · {t.category} · <span style={{ color: t.priority === 'urgent' || t.priority === 'high' ? 'var(--red)' : undefined }}>{t.priority}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Thread */}
        <div className="card" style={{ minHeight: 300 }}>
          {!sel ? (
            <div className="empty">Select a ticket to view the conversation.</div>
          ) : (
            <>
              <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                <div className="row" style={{ gap: 10 }}>
                  <Avatar name={sel.user?.name ?? '?'} seed={sel.user?.id} size={38} />
                  <div>
                    <div style={{ fontWeight: 700 }}>{sel.subject}</div>
                    <div className="cell-sub">@{sel.user?.username} · {sel.user?.email}</div>
                  </div>
                </div>
                <div className="row" style={{ gap: 6 }}>
                  <select className="select-inline" value={sel.status} onChange={(e) => patch({ status: e.target.value })}>
                    {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                  </select>
                  <select className="select-inline" value={sel.priority} onChange={(e) => patch({ priority: e.target.value })}>
                    {PRIORITIES.map((p) => <option key={p} value={p}>{p}</option>)}
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gap: 10, margin: '16px 0' }}>
                {sel.messages?.map((m) => (
                  <div key={m.id} style={{
                    justifySelf: m.authorRole === 'admin' ? 'end' : 'start',
                    maxWidth: '80%',
                    background: m.internal ? 'rgba(245,158,11,0.10)' : m.authorRole === 'admin' ? 'var(--primary)' : 'var(--surface, #f1f5f9)',
                    color: m.authorRole === 'admin' && !m.internal ? '#fff' : 'var(--text)',
                    border: m.internal ? '1px dashed var(--amber, #f59e0b)' : '1px solid var(--border)',
                    borderRadius: 12, padding: '9px 12px', fontSize: 13.5,
                  }}>
                    {m.internal && <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--amber, #b45309)', marginBottom: 2 }}>INTERNAL NOTE</div>}
                    {m.body}
                    <div style={{ fontSize: 10.5, opacity: 0.7, marginTop: 3 }}>{new Date(m.createdAt).toLocaleString()}</div>
                  </div>
                ))}
              </div>

              <textarea value={reply} onChange={(e) => setReply(e.target.value)} rows={3} placeholder={internal ? 'Internal note (not shown to the user)…' : 'Reply to the customer…'} style={{ width: '100%' }} />
              <div className="row" style={{ justifyContent: 'space-between', marginTop: 8, flexWrap: 'wrap', gap: 8 }}>
                <label className="row" style={{ gap: 6, fontSize: 13, cursor: 'pointer' }}>
                  <input type="checkbox" checked={internal} onChange={(e) => setInternal(e.target.checked)} /> Internal note
                </label>
                <button className="btn" disabled={busy || !reply.trim()} onClick={send}>{busy ? 'Sending…' : internal ? 'Add note' : 'Send reply'}</button>
              </div>
            </>
          )}
        </div>
      </div>
    </Shell>
  );
}
