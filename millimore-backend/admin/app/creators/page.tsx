'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';

interface Application {
  id: string;
  userId: string;
  user: {
    id: string;
    name: string;
    username: string;
    email: string | null;
    phone: string | null;
    residenceCountry: string | null;
  };
  status: string;
  market: string;
  platform: string;
  verification: {
    platform: string;
    server: string | null;
    account: string | null;
    statementUrl: string | null;
    hasInvestorPassword: boolean;
  };
  createdAt: string;
}

export default function CreatorQueuePage() {
  const [apps, setApps] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [workingId, setWorkingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setApps(await apiFetch<Application[]>('/admin/creators/pending'));
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(app: Application, action: 'approve' | 'reject') {
    let body: Record<string, string> = {};
    if (action === 'reject') {
      const reason = window.prompt(`Reject ${app.user.name}'s application — reason?`);
      if (!reason) return;
      body = { reason };
    } else {
      const note = window.prompt(`Approve ${app.user.name}? Optional note:`) ?? '';
      body = note ? { note } : {};
    }
    setWorkingId(app.id);
    setError(null);
    try {
      await apiFetch(`/admin/creators/${app.id}/${action}`, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      setApps((prev) => prev.filter((a) => a.id !== app.id)); // drop from queue
    } catch (err: any) {
      setError(err.message);
    } finally {
      setWorkingId(null);
    }
  }

  return (
    <Shell>
      <h1>Creator verification queue</h1>
      <p className="subtle">
        Approving flips the applicant to <code>creatorStatus: approved</code>; the app is
        notified on its next <code>/creator/status</code> poll.
      </p>

      {error && <div className="error">{error}</div>}

      {loading ? (
        <div className="empty">Loading…</div>
      ) : apps.length === 0 ? (
        <div className="empty">🎉 Nothing pending. The queue is clear.</div>
      ) : (
        apps.map((app) => (
          <div key={app.id} className="queue-item">
            <div className="row">
              <div style={{ fontWeight: 700, fontSize: 16 }}>{app.user.name}</div>
              <span className="pill role-creator">@{app.user.username}</span>
              <span className="pill status-pending">pending</span>
              <div className="spacer" />
              <span className="subtle">{new Date(app.createdAt).toLocaleString()}</span>
            </div>

            <div className="kv">
              <div className="k">Contact</div>
              <div>
                {app.user.email || '—'} {app.user.phone ? `· ${app.user.phone}` : ''}
              </div>
              <div className="k">Residence</div>
              <div>{app.user.residenceCountry || '—'}</div>
              <div className="k">Market / Platform</div>
              <div>
                {app.market} · {app.platform}
              </div>
              <div className="k">MT server</div>
              <div>{app.verification.server || '—'}</div>
              <div className="k">MT account</div>
              <div>{app.verification.account || '—'}</div>
              <div className="k">Investor password</div>
              <div>
                {app.verification.hasInvestorPassword ? (
                  <span className="subtle">provided (encrypted, not shown)</span>
                ) : (
                  <span className="subtle">not provided</span>
                )}
              </div>
              <div className="k">Statement</div>
              <div>
                {app.verification.statementUrl ? (
                  <a href={app.verification.statementUrl} target="_blank" rel="noreferrer">
                    View statement
                  </a>
                ) : (
                  '—'
                )}
              </div>
            </div>

            <div className="row">
              <button
                className="btn success"
                disabled={workingId === app.id}
                onClick={() => decide(app, 'approve')}
              >
                Approve
              </button>
              <button
                className="btn danger"
                disabled={workingId === app.id}
                onClick={() => decide(app, 'reject')}
              >
                Reject
              </button>
            </div>
          </div>
        ))
      )}
    </Shell>
  );
}
