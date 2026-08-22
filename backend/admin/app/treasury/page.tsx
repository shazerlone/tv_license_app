'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill, Icons } from '../../components/ui';

interface Summary {
  addresses: number;
  totals: { deposited: number; swept: number; unswept: number; currency: string };
  sweeps: { pending: number; failed: number };
  byNetwork: { network: string; addresses: number; deposited: number; swept: number; unswept: number }[];
  sweepConfig: { active: boolean; mode: string };
}
interface AddrRow {
  id: string;
  userId: string;
  user: { username: string; name: string } | null;
  network: string;
  address: string;
  deposited: number;
  swept: number;
  unswept: number;
  lastDepositAt: string | null;
  lastSweep: { status: string; at: string; txRef: string | null; error: string | null } | null;
}
interface SweepRow {
  id: string; network: string; fromAddress: string; toAddress: string;
  amount: number; status: string; txRef: string | null; error: string | null; createdAt: string;
}

const money = (n: number) => `$${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const NET_LABEL: Record<string, string> = { tron: 'TRON (TRC-20)', ethereum: 'Ethereum (ERC-20)', bsc: 'BSC (BEP-20)' };
const SWEEP_TONE: Record<string, 'amber' | 'green' | 'red' | 'slate' | 'blue'> = {
  pending: 'amber', broadcast: 'blue', confirmed: 'green', failed: 'red',
};
const shortAddr = (a: string) => (a.length > 14 ? `${a.slice(0, 8)}…${a.slice(-5)}` : a);
const FILTERS = ['all', 'unswept', 'failed'] as const;

export default function TreasuryPage() {
  const [sum, setSum] = useState<Summary | null>(null);
  const [rows, setRows] = useState<AddrRow[]>([]);
  const [sweeps, setSweeps] = useState<SweepRow[]>([]);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('all');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const [s, a, sw] = await Promise.all([
        apiFetch<Summary>('/admin/treasury/summary'),
        apiFetch<{ items: AddrRow[] }>(`/admin/treasury/addresses?limit=100${filter !== 'all' ? `&filter=${filter}` : ''}`),
        apiFetch<{ items: SweepRow[] }>('/admin/treasury/sweeps?limit=25'),
      ]);
      setSum(s); setRows(a.items); setSweeps(sw.items);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => { load(); }, [load]);

  async function sweepAll() {
    if (!window.confirm('Run a consolidation sweep now? This moves all funded addresses to the master wallet.')) return;
    setBusy('all'); setNote(null);
    try {
      const r = await apiFetch<{ scanned: number; swept: number }>('/admin/treasury/sweep', { method: 'POST' });
      setNote(`Batch sweep: ${r.swept} of ${r.scanned} address(es) swept.`);
      await load();
    } catch (e: any) { setNote(`Sweep failed: ${e.message}`); }
    finally { setBusy(null); }
  }

  async function sweepOne(row: AddrRow) {
    setBusy(row.id); setNote(null);
    try {
      const r = await apiFetch<{ status: string; reason?: string }>(`/admin/treasury/addresses/${row.id}/sweep`, { method: 'POST' });
      setNote(`${shortAddr(row.address)}: ${r.status}${r.reason ? ` — ${r.reason}` : ''}`);
      await load();
    } catch (e: any) { setNote(`Sweep failed: ${e.message}`); }
    finally { setBusy(null); }
  }

  async function reconcile() {
    setBusy('reconcile'); setNote(null);
    try {
      const r = await apiFetch<{ checked: number; onChainUnswept: number }>('/admin/treasury/reconcile', { method: 'POST' });
      setNote(`On-chain reconcile: ${money(r.onChainUnswept)} unswept across ${r.checked} funded address(es).`);
    } catch (e: any) { setNote(`Reconcile failed: ${e.message}`); }
    finally { setBusy(null); }
  }

  const t = sum?.totals;

  return (
    <Shell>
      <div className="page-head">
        <h1>Treasury</h1>
        <p className="lead">
          Every user deposit address, how much has been consolidated to the master wallet, and what’s
          still waiting — so nothing is ever missed. Deposits credit instantly; sweeps run in the
          background{sum ? ` (${sum.sweepConfig.active ? `auto · ${sum.sweepConfig.mode}` : 'auto-sweep off'})` : ''}.
        </p>
      </div>

      {err && <div className="error">{err}</div>}
      {note && <div className="card" style={{ marginBottom: 14, fontSize: 13.5 }}>{note}</div>}

      {/* KPI tiles */}
      <div className="cards" style={{ marginBottom: 8 }}>
        <div className="card"><div className="stat-tile">
          <div className="stat-top"><div className="stat-ico blue"><Icons.users /></div></div>
          <div className="stat">{sum ? sum.addresses.toLocaleString() : '—'}</div>
          <div className="stat-label">Deposit addresses</div>
        </div></div>
        <div className="card"><div className="stat-tile">
          <div className="stat-top"><div className="stat-ico green"><Icons.spark /></div></div>
          <div className="stat">{t ? money(t.deposited) : '—'}</div>
          <div className="stat-label">Total deposited</div>
        </div></div>
        <div className="card"><div className="stat-tile">
          <div className="stat-top"><div className="stat-ico blue"><Icons.approved /></div></div>
          <div className="stat">{t ? money(t.swept) : '—'}</div>
          <div className="stat-label">Swept to master</div>
        </div></div>
        <div className="card"><div className="stat-tile">
          <div className="stat-top"><div className="stat-ico amber"><Icons.queue /></div></div>
          <div className="stat">{t ? money(t.unswept) : '—'}</div>
          <div className="stat-label">Awaiting sweep</div>
          {sum && sum.sweeps.pending > 0 ? <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{sum.sweeps.pending} in flight</div> : null}
        </div></div>
        <div className="card"><div className="stat-tile">
          <div className="stat-top"><div className={`stat-ico ${sum && sum.sweeps.failed > 0 ? 'red' : 'slate'}`}><Icons.approved /></div></div>
          <div className="stat">{sum ? sum.sweeps.failed.toLocaleString() : '—'}</div>
          <div className="stat-label">Failed sweeps</div>
          {sum && sum.sweeps.failed > 0 ? <div className="muted" style={{ fontSize: 12, marginTop: 2, color: 'var(--red-700)' }}>needs attention</div> : null}
        </div></div>
      </div>

      {/* Actions */}
      <div className="row" style={{ gap: 8, margin: '4px 0 18px', flexWrap: 'wrap' }}>
        <button className="btn" disabled={busy !== null} onClick={sweepAll}>{busy === 'all' ? 'Sweeping…' : 'Sweep now'}</button>
        <button className="btn ghost" disabled={busy !== null} onClick={reconcile}>{busy === 'reconcile' ? 'Checking…' : 'Reconcile on-chain'}</button>
        <button className="btn ghost" disabled={loading} onClick={load}>Refresh</button>
        {sum && !sum.sweepConfig.active && (
          <span className="pill amber" style={{ alignSelf: 'center' }}>Auto-sweep is off — configure Gas Pump + KMS</span>
        )}
      </div>

      {/* Per-network breakdown */}
      <div className="nav-label" style={{ marginBottom: 8 }}>By network</div>
      <div className="cards" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', marginBottom: 22 }}>
        {(sum?.byNetwork ?? []).map((n) => (
          <div key={n.network} className="card" style={{ padding: 16 }}>
            <div className="row" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
              <strong>{NET_LABEL[n.network] ?? n.network}</strong>
              <Pill tone="slate" plain>{n.addresses} addr</Pill>
            </div>
            <div className="row" style={{ justifyContent: 'space-between', fontSize: 13 }}><span className="muted">Deposited</span><span className="mono">{money(n.deposited)}</span></div>
            <div className="row" style={{ justifyContent: 'space-between', fontSize: 13 }}><span className="muted">Swept</span><span className="mono">{money(n.swept)}</span></div>
            <div className="row" style={{ justifyContent: 'space-between', fontSize: 13, marginTop: 2 }}><span className="muted">Awaiting</span><strong className="mono">{money(n.unswept)}</strong></div>
          </div>
        ))}
      </div>

      {/* Addresses table */}
      <div className="row" style={{ justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 8 }}>
        <div className="nav-label" style={{ margin: 0 }}>Addresses</div>
        <div className="row" style={{ gap: 6 }}>
          {FILTERS.map((f) => (
            <button key={f} className={`btn sm ${filter === f ? '' : 'ghost'}`} onClick={() => setFilter(f)} style={{ textTransform: 'capitalize' }}>{f}</button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="panel empty">Loading treasury…</div>
      ) : rows.length === 0 ? (
        <div className="panel empty">No addresses{filter !== 'all' ? ` matching “${filter}”` : ''}.</div>
      ) : (
        <div className="panel" style={{ overflowX: 'auto' }}>
          <table className="tbl">
            <thead>
              <tr>
                <th>User</th><th>Network</th><th>Address</th>
                <th style={{ textAlign: 'right' }}>Deposited</th>
                <th style={{ textAlign: 'right' }}>Swept</th>
                <th style={{ textAlign: 'right' }}>Awaiting</th>
                <th>Last sweep</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} style={r.lastSweep?.status === 'failed' ? { background: 'rgba(239,68,68,0.05)' } : undefined}>
                  <td>
                    <div className="row" style={{ gap: 10 }}>
                      <Avatar name={r.user?.name ?? r.userId} seed={r.userId} size={30} />
                      <div><div className="name">{r.user?.name ?? '—'}</div><div className="cell-sub">@{r.user?.username ?? r.userId.slice(0, 8)}</div></div>
                    </div>
                  </td>
                  <td style={{ textTransform: 'uppercase', fontSize: 12 }}>{r.network}</td>
                  <td>
                    <button
                      className="mono"
                      title="Copy address"
                      onClick={() => { navigator.clipboard?.writeText(r.address); setNote(`Copied ${shortAddr(r.address)}`); }}
                      style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', color: 'var(--text)', fontSize: 12.5 }}
                    >
                      {shortAddr(r.address)}
                    </button>
                  </td>
                  <td className="mono" style={{ textAlign: 'right' }}>{money(r.deposited)}</td>
                  <td className="mono" style={{ textAlign: 'right', color: 'var(--muted)' }}>{money(r.swept)}</td>
                  <td className="mono" style={{ textAlign: 'right', fontWeight: 700 }}>{money(r.unswept)}</td>
                  <td>{r.lastSweep ? <Pill tone={SWEEP_TONE[r.lastSweep.status] ?? 'slate'}>{r.lastSweep.status}</Pill> : <span className="muted" style={{ fontSize: 12 }}>never</span>}</td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn sm ghost" disabled={busy !== null || r.unswept <= 0} onClick={() => sweepOne(r)}>Sweep</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Sweep audit trail */}
      {sweeps.length > 0 && (
        <>
          <div className="nav-label" style={{ margin: '24px 0 10px' }}>Recent sweeps</div>
          <div className="panel" style={{ overflowX: 'auto' }}>
            <table className="tbl">
              <thead>
                <tr><th>When</th><th>Network</th><th>From</th><th style={{ textAlign: 'right' }}>Amount</th><th>Status</th><th>Tx</th></tr>
              </thead>
              <tbody>
                {sweeps.map((s) => (
                  <tr key={s.id}>
                    <td className="muted" style={{ fontSize: 12.5 }}>{new Date(s.createdAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</td>
                    <td style={{ textTransform: 'uppercase', fontSize: 12 }}>{s.network}</td>
                    <td className="mono" style={{ fontSize: 12.5 }}>{shortAddr(s.fromAddress)}</td>
                    <td className="mono" style={{ textAlign: 'right' }}>{money(s.amount)}</td>
                    <td><Pill tone={SWEEP_TONE[s.status] ?? 'slate'}>{s.status}</Pill>{s.error ? <div className="cell-sub" style={{ color: 'var(--red-700)' }}>{s.error}</div> : null}</td>
                    <td className="mono" style={{ fontSize: 12 }}>{s.txRef ? shortAddr(s.txRef) : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </Shell>
  );
}
