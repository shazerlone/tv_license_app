'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Pill } from '../../components/ui';

interface Announcement {
  id: string; title: string; body: string; audience: string;
  requiredRead: boolean; active: boolean; createdAt: string; reads: number;
}

const AUDIENCES = ['all', 'followers', 'creators'];

export default function AnnouncementsPage() {
  const [rows, setRows] = useState<Announcement[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState('all');
  const [requiredRead, setRequiredRead] = useState(false);

  const load = useCallback(async () => {
    setErr(null);
    try { setRows(await apiFetch<Announcement[]>('/admin/announcements')); } catch (e: any) { setErr(e.message); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const create = async () => {
    if (!title.trim() || !body.trim()) return setErr('Title and message are required.');
    setBusy(true); setErr(null);
    try {
      await apiFetch('/admin/announcements', { method: 'POST', body: JSON.stringify({ title: title.trim(), body: body.trim(), audience, requiredRead }) });
      setTitle(''); setBody(''); setAudience('all'); setRequiredRead(false);
      load();
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  };

  const toggle = async (a: Announcement) => {
    try { await apiFetch(`/admin/announcements/${a.id}`, { method: 'PATCH', body: JSON.stringify({ active: !a.active }) }); load(); }
    catch (e: any) { setErr(e.message); }
  };
  const remove = async (a: Announcement) => {
    if (!window.confirm(`Delete "${a.title}"?`)) return;
    try { await apiFetch(`/admin/announcements/${a.id}`, { method: 'DELETE' }); load(); }
    catch (e: any) { setErr(e.message); }
  };

  return (
    <Shell>
      <div className="page-head">
        <h1>Announcements</h1>
        <p className="lead">Broadcast messages to the app’s notification bell. Target an audience and require acknowledgement.</p>
      </div>

      {err && <div className="error">{err}</div>}

      <div className="card" style={{ marginBottom: 20 }}>
        <div style={{ fontWeight: 700, marginBottom: 12 }}>New announcement</div>
        <input placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} style={{ width: '100%', marginBottom: 10 }} />
        <textarea placeholder="Message…" value={body} onChange={(e) => setBody(e.target.value)} rows={3} style={{ width: '100%', marginBottom: 10 }} />
        <div className="row" style={{ gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          <label className="row" style={{ gap: 6, fontSize: 13 }}>
            Audience
            <select value={audience} onChange={(e) => setAudience(e.target.value)}>
              {AUDIENCES.map((a) => <option key={a} value={a}>{a}</option>)}
            </select>
          </label>
          <label className="row" style={{ gap: 6, fontSize: 13, cursor: 'pointer' }}>
            <input type="checkbox" checked={requiredRead} onChange={(e) => setRequiredRead(e.target.checked)} /> Required read
          </label>
          <div className="spacer" style={{ flex: 1 }} />
          <button className="btn" disabled={busy} onClick={create}>{busy ? 'Publishing…' : 'Publish'}</button>
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="panel empty">No announcements yet.</div>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {rows.map((a) => (
            <div key={a.id} className="card">
              <div className="row" style={{ justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
                <div style={{ fontWeight: 700 }}>{a.title}</div>
                <div className="row" style={{ gap: 6 }}>
                  <Pill tone="slate">{a.audience}</Pill>
                  {a.requiredRead && <Pill tone="amber">required</Pill>}
                  <Pill tone={a.active ? 'green' : 'slate'}>{a.active ? 'active' : 'inactive'}</Pill>
                </div>
              </div>
              <div className="muted" style={{ fontSize: 13.5, margin: '8px 0' }}>{a.body}</div>
              <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
                <span className="cell-sub">{new Date(a.createdAt).toLocaleDateString()} · {a.reads} read</span>
                <div className="row" style={{ gap: 6 }}>
                  <button className="btn ghost sm" onClick={() => toggle(a)}>{a.active ? 'Deactivate' : 'Activate'}</button>
                  <button className="btn danger sm" onClick={() => remove(a)}>Delete</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </Shell>
  );
}
