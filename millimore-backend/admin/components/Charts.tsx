'use client';

/**
 * Dependency-free SVG charts, styled with the admin design tokens. Kept simple
 * and crisp (Linear/Stripe-tier): thin lines, soft area fills, muted gridlines,
 * no chart library (works in the static export under a strict CSP).
 */

export interface Pt {
  date: string;
  value: number;
}

const fmtMoney = (n: number) =>
  n >= 1000 ? `$${(n / 1000).toFixed(n >= 100000 ? 0 : 1)}k` : `$${Math.round(n)}`;
const fmtNum = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${Math.round(n)}`);
const shortDate = (d: string) => {
  const dt = new Date(d + 'T00:00:00Z');
  return dt.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
};

export function LineChart({
  points,
  color = 'var(--primary)',
  height = 200,
  money = false,
}: {
  points: Pt[];
  color?: string;
  height?: number;
  money?: boolean;
}) {
  if (!points || points.length < 2) return <div className="muted" style={{ padding: 24 }}>Not enough data yet.</div>;
  const W = 760;
  const H = height;
  const padL = 44;
  const padR = 12;
  const padT = 12;
  const padB = 26;
  const values = points.map((p) => p.value);
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  const stepX = (W - padL - padR) / (points.length - 1);
  const x = (i: number) => padL + i * stepX;
  const y = (v: number) => padT + (1 - (v - min) / span) * (H - padT - padB);
  const fmt = money ? fmtMoney : fmtNum;

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`).join(' ');
  const area = `${line} L ${x(points.length - 1).toFixed(1)} ${(H - padB).toFixed(1)} L ${x(0).toFixed(1)} ${(H - padB).toFixed(1)} Z`;
  const ticks = 4;
  const gy = Array.from({ length: ticks + 1 }, (_, i) => min + (span * i) / ticks);
  const labelEvery = Math.ceil(points.length / 6);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" style={{ display: 'block' }}>
      <defs>
        <linearGradient id={`lc-${color.replace(/\W/g, '')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.18" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {gy.map((v, i) => (
        <g key={i}>
          <line x1={padL} y1={y(v)} x2={W - padR} y2={y(v)} stroke="var(--border)" strokeWidth="1" />
          <text x={padL - 8} y={y(v) + 3.5} textAnchor="end" fontSize="10.5" fill="var(--text-muted)">{fmt(v)}</text>
        </g>
      ))}
      <path d={area} fill={`url(#lc-${color.replace(/\W/g, '')})`} />
      <path d={line} fill="none" stroke={color} strokeWidth="2.2" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={x(points.length - 1)} cy={y(values[values.length - 1])} r="3.2" fill={color} />
      {points.map((p, i) =>
        i % labelEvery === 0 || i === points.length - 1 ? (
          <text key={i} x={x(i)} y={H - 8} textAnchor="middle" fontSize="10.5" fill="var(--text-muted)">{shortDate(p.date)}</text>
        ) : null,
      )}
    </svg>
  );
}

export function BarsChart({
  points,
  seriesB,
  colorA = 'var(--green)',
  colorB = 'var(--red)',
  height = 200,
}: {
  points: Pt[]; // series A (e.g. deposits)
  seriesB?: Pt[]; // series B (e.g. withdrawals)
  colorA?: string;
  colorB?: string;
  height?: number;
}) {
  if (!points || points.length === 0) return <div className="muted" style={{ padding: 24 }}>No data yet.</div>;
  const W = 760;
  const H = height;
  const padL = 44;
  const padR = 12;
  const padT = 12;
  const padB = 26;
  const all = [...points.map((p) => p.value), ...(seriesB ?? []).map((p) => p.value)];
  const max = Math.max(...all, 1);
  const n = points.length;
  const groupW = (W - padL - padR) / n;
  const two = !!seriesB;
  const barW = Math.max(2, (groupW * 0.6) / (two ? 2 : 1));
  const y = (v: number) => padT + (1 - v / max) * (H - padT - padB);
  const ticks = 4;
  const gy = Array.from({ length: ticks + 1 }, (_, i) => (max * i) / ticks);
  const labelEvery = Math.ceil(n / 6);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" style={{ display: 'block' }}>
      {gy.map((v, i) => (
        <g key={i}>
          <line x1={padL} y1={y(v)} x2={W - padR} y2={y(v)} stroke="var(--border)" strokeWidth="1" />
          <text x={padL - 8} y={y(v) + 3.5} textAnchor="end" fontSize="10.5" fill="var(--text-muted)">{fmtMoney(v)}</text>
        </g>
      ))}
      {points.map((p, i) => {
        const cx = padL + i * groupW + groupW / 2;
        const aX = two ? cx - barW - 1 : cx - barW / 2;
        const bVal = seriesB?.[i]?.value ?? 0;
        return (
          <g key={i}>
            <rect x={aX} y={y(p.value)} width={barW} height={Math.max(0, H - padB - y(p.value))} rx="2" fill={colorA} />
            {two && <rect x={cx + 1} y={y(bVal)} width={barW} height={Math.max(0, H - padB - y(bVal))} rx="2" fill={colorB} />}
            {(i % labelEvery === 0 || i === n - 1) && (
              <text x={cx} y={H - 8} textAnchor="middle" fontSize="10.5" fill="var(--text-muted)">{shortDate(p.date)}</text>
            )}
          </g>
        );
      })}
    </svg>
  );
}
