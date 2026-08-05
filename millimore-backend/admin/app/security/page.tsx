'use client';

import { useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';

export default function SecurityPage() {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [setup, setSetup] = useState<{ secret: string; otpauthUrl: string } | null>(null);
  const [code, setCode] = useState('');
  const [backup, setBackup] = useState<string[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = () => apiFetch<{ enabled: boolean }>('/2fa').then((r) => setEnabled(r.enabled)).catch(() => setEnabled(false));
  useEffect(() => { load(); }, []);

  const beginSetup = async () => {
    setErr(null); setBusy(true);
    try { setSetup(await apiFetch('/2fa/setup', { method: 'POST' })); }
    catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  };
  const confirmEnable = async () => {
    setErr(null); setBusy(true);
    try {
      const r = await apiFetch<{ backupCodes: string[] }>('/2fa/enable', { method: 'POST', body: JSON.stringify({ code }) });
      setBackup(r.backupCodes); setSetup(null); setCode(''); await load();
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  };
  const disable = async () => {
    const c = window.prompt('Enter a current 2FA code (or a backup code) to disable:');
    if (!c) return;
    setErr(null); setBusy(true);
    try { await apiFetch('/2fa/disable', { method: 'POST', body: JSON.stringify({ code: c }) }); setBackup(null); await load(); }
    catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  };

  return (
    <Shell>
      <div className="page-head">
        <h1>Security</h1>
        <p className="lead">Protect your admin account with two-factor authentication (an authenticator app like Google Authenticator or Authy).</p>
      </div>

      {err && <div className="error">{err}</div>}

      <div className="card" style={{ maxWidth: 560 }}>
        <div className="row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ fontWeight: 700 }}>Two-factor authentication</div>
            <div className="muted" style={{ fontSize: 13 }}>{enabled === null ? '…' : enabled ? 'Enabled — a code is required at login.' : 'Not enabled.'}</div>
          </div>
          {enabled ? (
            <button className="btn danger sm" onClick={disable} disabled={busy}>Disable</button>
          ) : !setup ? (
            <button className="btn" onClick={beginSetup} disabled={busy}>Enable 2FA</button>
          ) : null}
        </div>

        {setup && (
          <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
            <div style={{ fontWeight: 600, marginBottom: 6 }}>1. Add to your authenticator app</div>
            <div className="muted" style={{ fontSize: 13, marginBottom: 6 }}>Scan the setup link, or enter this key manually:</div>
            <div className="mono" style={{ background: 'var(--surface, #f1f5f9)', border: '1px solid var(--border)', borderRadius: 10, padding: '10px 12px', wordBreak: 'break-all', fontSize: 14, letterSpacing: 1 }}>{setup.secret}</div>
            <div className="muted" style={{ fontSize: 11.5, marginTop: 6, wordBreak: 'break-all' }}>{setup.otpauthUrl}</div>

            <div style={{ fontWeight: 600, margin: '14px 0 6px' }}>2. Enter the 6-digit code</div>
            <div className="row" style={{ gap: 8 }}>
              <input value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" placeholder="123456" style={{ width: 140 }} />
              <button className="btn" onClick={confirmEnable} disabled={busy || code.length < 4}>Verify & enable</button>
            </div>
          </div>
        )}

        {backup && (
          <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
            <div style={{ fontWeight: 700, color: 'var(--amber, #b45309)' }}>Save your backup codes</div>
            <div className="muted" style={{ fontSize: 13, margin: '4px 0 10px' }}>Each works once if you lose your phone. Store them somewhere safe — they won’t be shown again.</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
              {backup.map((c) => <div key={c} className="mono" style={{ background: 'var(--surface, #f1f5f9)', borderRadius: 8, padding: '6px 10px', textAlign: 'center', letterSpacing: 1 }}>{c}</div>)}
            </div>
          </div>
        )}
      </div>
    </Shell>
  );
}
