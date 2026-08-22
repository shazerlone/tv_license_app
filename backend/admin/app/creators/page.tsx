'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { apiFetch } from '../../lib/api';
import { Avatar, Pill } from '../../components/ui';

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
      setApps((prev) => prev.filter((a) => a.id !== app.id));
    } catch (err: any) {
      setError(err.message);
    } finally {
      setWorkingId(null);
    }
  }

  const Row = ({ k, v }: { k: string; v: React.ReactNode }) => (
    <div className="kv">
      <div className="k">{k}</div>
      <div className="v">{v}</div>
    </div>
  );

  return (
    <Shell>
      <div className="page-head">
        <h1>Creator verification</h1>
        <p className="lead">
          Review verification applications. Approving flips the applicant to{' '}
          <code>creatorStatus: approved</code>; the app picks it up on its next{' '}
          <code>/creator/status</code> poll.
        </p>
      </div>

      {error && <div className="error">{error}</div>}

      {loading ? (
        <div className="panel empty">Loading applications…</div>
      ) : apps.length === 0 ? (
        <div className="panel empty">
          <div className="big">✓</div>
          The queue is clear — no applications waiting for review.
        </div>
      ) : (
        apps.map((app) => (
          <div key={app.id} className="queue-item">
            <div className="queue-head">
              <Avatar name={app.user.name} seed={app.userId} size={44} />
              <div style={{ flex: 1 }}>
                <div className="name">{app.user.name}</div>
                <div className="cell-sub">@{app.user.username}</div>
              </div>
              <Pill tone="amber">pending</Pill>
              <span className="muted" style={{ fontSize: 12.5 }}>
                {new Date(app.createdAt).toLocaleDateString(undefined, {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                })}
              </span>
            </div>

            <div className="kv-grid">
              <Row k="Email" v={app.user.email || <span className="muted">—</span>} />
              <Row k="Phone" v={<span className="mono">{app.user.phone || '—'}</span>} />
              <Row k="Residence" v={app.user.residenceCountry || '—'} />
              <Row k="Market · Platform" v={`${app.market} · ${app.platform}`} />
              <Row k="MT server" v={app.verification.server || '—'} />
              <Row k="MT account" v={<span className="mono">{app.verification.account || '—'}</span>} />
              <Row
                k="Investor password"
                v={
                  app.verification.hasInvestorPassword ? (
                    <Pill tone="green" plain>
                      provided · encrypted
                    </Pill>
                  ) : (
                    <span className="muted">not provided</span>
                  )
                }
              />
              <Row
                k="Statement"
                v={
                  app.verification.statementUrl ? (
                    <a href={app.verification.statementUrl} target="_blank" rel="noreferrer">
                      View statement ↗
                    </a>
                  ) : (
                    <span className="muted">—</span>
                  )
                }
              />
            </div>

            <div className="row">
              <button
                className="btn success"
                disabled={workingId === app.id}
                onClick={() => decide(app, 'approve')}
              >
                Approve creator
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
