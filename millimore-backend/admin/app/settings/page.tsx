'use client';

import { useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';

interface Settings {
  platformFeeShare: number;
  maxLeverage: number;
  defaultLeverage: number;
  minDeposit: number;
  minWithdrawal: number;
  maxWithdrawalPerTx: number;
  maxWithdrawalPerDay: number;
  depositAutoConfirm: boolean;
  kycRequiredForWithdrawal: boolean;
  cryptoEnabled: boolean;
  cardEnabled: boolean;
  bankEnabled: boolean;
  maintenanceMode: boolean;
  referralEnabled: boolean;
  referralRevenueShare: number;
  referralSignupBonus: number;
}

const NUM_FIELDS: { key: keyof Settings; label: string; hint?: string; step?: number }[] = [
  { key: 'platformFeeShare', label: "Millimore fee share", hint: '0–1 of the trader fee (0.30 = 30%)', step: 0.01 },
  { key: 'maxLeverage', label: 'Max leverage', hint: 'e.g. 500' },
  { key: 'defaultLeverage', label: 'Default leverage' },
  { key: 'minDeposit', label: 'Min deposit ($)' },
  { key: 'minWithdrawal', label: 'Min withdrawal ($)' },
  { key: 'maxWithdrawalPerTx', label: 'Max withdrawal / transaction ($)' },
  { key: 'maxWithdrawalPerDay', label: 'Max withdrawal / day ($)' },
  { key: 'referralRevenueShare', label: 'Referral revenue share', hint: '0–1 of Millimore’s fee paid to referrers (0.10 = 10%)', step: 0.01 },
  { key: 'referralSignupBonus', label: 'Referral signup bonus ($)', hint: 'One-time, on a referral’s first deposit' },
];

const BOOL_FIELDS: { key: keyof Settings; label: string; hint?: string }[] = [
  { key: 'depositAutoConfirm', label: 'Auto-confirm deposits', hint: 'Off = admin approves each deposit (production)' },
  { key: 'kycRequiredForWithdrawal', label: 'Require KYC to withdraw' },
  { key: 'cryptoEnabled', label: 'Crypto deposits enabled' },
  { key: 'cardEnabled', label: 'Card deposits enabled' },
  { key: 'bankEnabled', label: 'Bank deposits enabled' },
  { key: 'referralEnabled', label: 'Referral program enabled' },
  { key: 'maintenanceMode', label: 'Maintenance mode' },
];

export default function SettingsPage() {
  const [s, setS] = useState<Settings | null>(null);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    apiFetch<Settings>('/admin/settings').then(setS).catch((e) => setErr(e.message));
  }, []);

  async function save() {
    if (!s) return;
    setSaving(true);
    setMsg(null);
    setErr(null);
    try {
      const saved = await apiFetch<Settings>('/admin/settings', {
        method: 'PATCH',
        body: JSON.stringify(s),
      });
      setS(saved);
      setMsg('Saved.');
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Shell>
      <div className="page-head">
        <h1>Settings</h1>
        <p className="lead">
          Platform-wide controls — the Millimore fee, leverage cap, deposit/withdrawal limits and
          payment methods. Changes take effect immediately (cached ~15s).
        </p>
      </div>

      {err && <div className="error">{err}</div>}
      {!s ? (
        <div className="panel empty">Loading settings…</div>
      ) : (
        <>
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="nav-label" style={{ marginBottom: 12 }}>Fees, leverage & limits</div>
            <div className="kv-grid">
              {NUM_FIELDS.map((f) => (
                <label key={f.key} className="kv" style={{ display: 'block' }}>
                  <div className="k">{f.label}</div>
                  <input
                    className="input"
                    type="number"
                    step={f.step ?? 1}
                    value={s[f.key] as number}
                    onChange={(e) => setS({ ...s, [f.key]: Number(e.target.value) })}
                    style={{ width: '100%', marginTop: 4 }}
                  />
                  {f.hint && <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{f.hint}</div>}
                </label>
              ))}
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div className="nav-label" style={{ marginBottom: 12 }}>Toggles</div>
            <div style={{ display: 'grid', gap: 10 }}>
              {BOOL_FIELDS.map((f) => (
                <label key={f.key} className="row" style={{ gap: 10, cursor: 'pointer', alignItems: 'center' }}>
                  <input
                    type="checkbox"
                    checked={s[f.key] as boolean}
                    onChange={(e) => setS({ ...s, [f.key]: e.target.checked })}
                  />
                  <span style={{ fontWeight: 600 }}>{f.label}</span>
                  {f.hint && <span className="muted" style={{ fontSize: 12 }}>— {f.hint}</span>}
                </label>
              ))}
            </div>
          </div>

          <div className="row" style={{ gap: 12, alignItems: 'center' }}>
            <button className="btn" onClick={save} disabled={saving}>
              {saving ? 'Saving…' : 'Save changes'}
            </button>
            {msg && <span style={{ color: 'var(--green, #16a34a)', fontWeight: 600 }}>{msg}</span>}
          </div>
        </>
      )}
    </Shell>
  );
}
