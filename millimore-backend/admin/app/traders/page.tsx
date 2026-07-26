'use client';

import { useCallback, useEffect, useState } from 'react';
import Shell from '../../components/Shell';
import { Avatar, Pill } from '../../components/ui';
import { EquityChart } from '../../components/EquityChart';
import { apiFetch, Trader, Post, PublicTrade, EquityPoint } from '../../lib/api';

function compact(n: number): string {
  if (Math.abs(n) >= 1_000_000) return (n / 1_000_000).toFixed(1).replace(/\.0$/, '') + 'M';
  if (Math.abs(n) >= 1_000) return (n / 1_000).toFixed(1).replace(/\.0$/, '') + 'K';
  return `${n}`;
}
const money = (n: number) => `$${compact(n)}`;

const CATEGORIES = ['All', 'Forex', 'Crypto', 'Gold', 'Indices'];

export default function TradersPage() {
  const [traders, setTraders] = useState<Trader[]>([]);
  const [category, setCategory] = useState('All');
  const [q, setQ] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Trader | null>(null);

  const load = useCallback(async () => {
    setError(null);
    const p = new URLSearchParams({ limit: '100', sort: 'copiers' });
    if (category !== 'All') p.set('category', category);
    if (q) p.set('q', q);
    try {
      const res = await apiFetch<{ items: Trader[] }>(`/traders?${p.toString()}`);
      setTraders(res.items);
    } catch (e: any) {
      setError(e.message);
    }
  }, [category, q]);

  useEffect(() => {
    const t = setTimeout(load, 200);
    return () => clearTimeout(t);
  }, [load]);

  return (
    <Shell>
      <div className="page-head">
        <h1>Traders</h1>
        <p className="lead">
          Every public trader profile on the platform — the data that powers the app's discover,
          profile and copy screens. Tap a trader to inspect their stats, equity curve, posts and trades.
        </p>
      </div>

      <div className="toolbar">
        <div className="search-wrap search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <circle cx="11" cy="11" r="8" />
            <path d="M21 21l-4.3-4.3" />
          </svg>
          <input placeholder="Search trader name or @username" value={q} onChange={(e) => setQ(e.target.value)} style={{ width: '100%' }} />
        </div>
        <select value={category} onChange={(e) => setCategory(e.target.value)}>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </div>

      {error && <div className="error">{error}</div>}

      <div className="trader-grid">
        {traders.map((t) => (
          <div key={t.id} className="trader-card" onClick={() => setSelected(t)}>
            <div className="head">
              <Avatar name={t.name} seed={t.id} size={44} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="nm">{t.name}</div>
                <div className="cell-sub">@{t.username}</div>
              </div>
              {t.isLive && <Pill tone="red">live</Pill>}
            </div>
            <div className="row" style={{ marginTop: 10, gap: 6 }}>
              <Pill tone="blue" plain>{t.category}</Pill>
              {t.isVerified && <Pill tone="green" plain>verified</Pill>}
            </div>
            <div className="mini-row">
              <div className="mini-stat">
                <div className={`n ${t.returnPercent >= 0 ? 'pos' : 'neg'}`}>
                  {t.returnPercent >= 0 ? '+' : ''}{t.returnPercent}%
                </div>
                <div className="l">{t.returnDays}d return</div>
              </div>
              <div className="mini-stat">
                <div className="n">{compact(t.copiers)}</div>
                <div className="l">Copiers</div>
              </div>
              <div className="mini-stat">
                <div className="n">{money(t.aum)}</div>
                <div className="l">AUM</div>
              </div>
            </div>
          </div>
        ))}
        {traders.length === 0 && !error && <div className="empty">No traders match.</div>}
      </div>

      {selected && <TraderDrawer trader={selected} onClose={() => setSelected(null)} />}
    </Shell>
  );
}

function TraderDrawer({ trader, onClose }: { trader: Trader; onClose: () => void }) {
  const [equity, setEquity] = useState<EquityPoint[]>([]);
  const [posts, setPosts] = useState<Post[]>([]);
  const [trades, setTrades] = useState<PublicTrade[]>([]);

  useEffect(() => {
    apiFetch<EquityPoint[]>(`/traders/${trader.id}/equity?range=30d`).then(setEquity).catch(() => {});
    apiFetch<Post[]>(`/traders/${trader.id}/posts`).then(setPosts).catch(() => {});
    apiFetch<PublicTrade[]>(`/traders/${trader.id}/trades`).then(setTrades).catch(() => {});
  }, [trader.id]);

  const kpi = (n: string, l: string, cls = '') => (
    <div className="kpi">
      <div className={`n ${cls}`}>{n}</div>
      <div className="l">{l}</div>
    </div>
  );

  return (
    <>
      <div className="backdrop" style={{ zIndex: 65 }} onClick={onClose} />
      <aside className="drawer open">
        <div className="drawer-inner">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <div className="row" style={{ gap: 12 }}>
              <Avatar name={trader.name} seed={trader.id} size={52} />
              <div>
                <div style={{ fontWeight: 800, fontSize: 18, letterSpacing: '-0.02em' }}>{trader.name}</div>
                <div className="cell-sub">@{trader.username}</div>
              </div>
            </div>
            <button className="drawer-close" onClick={onClose} aria-label="Close">×</button>
          </div>

          <div className="row" style={{ gap: 6, marginTop: 12 }}>
            <Pill tone="blue" plain>{trader.category}</Pill>
            {trader.isVerified && <Pill tone="green">verified</Pill>}
            {trader.isLive && <Pill tone="red">live now</Pill>}
          </div>
          {trader.bio && <p className="subtle" style={{ marginTop: 12 }}>{trader.bio}</p>}
          {trader.tags.length > 0 && (
            <div className="row" style={{ gap: 6, marginTop: 8 }}>
              {trader.tags.map((tag) => <Pill key={tag} plain>{tag}</Pill>)}
            </div>
          )}

          <div className="section-title">Equity · last 30 days</div>
          <div className="card" style={{ padding: 12 }}>
            <EquityChart points={equity} />
          </div>

          <div className="stat-grid2" style={{ marginTop: 14 }}>
            {kpi(`${trader.returnPercent >= 0 ? '+' : ''}${trader.returnPercent}%`, `${trader.returnDays}-day return`, trader.returnPercent >= 0 ? 'pos' : 'neg')}
            {kpi(`${trader.winRate}%`, 'Win rate')}
            {kpi(compact(trader.copiers), 'Copiers')}
            {kpi(compact(trader.followers), 'Followers')}
            {kpi(money(trader.aum), 'AUM')}
            {kpi(`${trader.maxDrawdown}%`, 'Max drawdown', 'neg')}
            {kpi(`${trader.totalTrades}`, 'Total trades')}
          </div>

          <div className="section-title">Recent posts</div>
          {posts.length === 0 ? (
            <div className="muted">No posts yet.</div>
          ) : (
            posts.slice(0, 5).map((p) => (
              <div key={p.id} className="post-row">
                <div className="meta">
                  <Pill tone="blue" plain>{p.type}</Pill>
                  {p.pair && <span className="cell-sub mono">{p.pair}</span>}
                  <span className="spacer" />
                  <span className="cell-sub">♥ {p.likes} · 💬 {p.comments}</span>
                </div>
                {p.title && <div style={{ fontWeight: 600, marginBottom: 2 }}>{p.title}</div>}
                <div className="subtle">{p.content}</div>
              </div>
            ))
          )}

          <div className="section-title">Recent trades</div>
          <div className="panel">
            <table>
              <thead>
                <tr><th>Pair</th><th>Side</th><th>Status</th><th style={{ textAlign: 'right' }}>P/L</th></tr>
              </thead>
              <tbody>
                {trades.slice(0, 8).map((t) => (
                  <tr key={t.id}>
                    <td className="mono">{t.pair}</td>
                    <td>{t.isBuy ? 'Buy' : 'Sell'}</td>
                    <td><Pill tone={t.status === 'active' ? 'amber' : 'slate'} plain>{t.status}</Pill></td>
                    <td style={{ textAlign: 'right' }} className={t.pnlAmount >= 0 ? 'pos' : 'neg'}>
                      {t.pnlAmount >= 0 ? '+' : ''}{t.pnlAmount} ({t.pnlPercent}%)
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </aside>
    </>
  );
}
