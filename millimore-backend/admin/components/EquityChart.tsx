'use client';

import { EquityPoint } from '../lib/api';

/** Compact SVG area chart for a trader's equity curve. No chart library. */
export function EquityChart({ points, height = 120 }: { points: EquityPoint[]; height?: number }) {
  if (!points || points.length < 2) {
    return <div className="muted" style={{ padding: 16 }}>No equity data.</div>;
  }
  const W = 600;
  const H = height;
  const pad = 6;
  const values = points.map((p) => p.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const stepX = (W - pad * 2) / (points.length - 1);
  const x = (i: number) => pad + i * stepX;
  const y = (v: number) => pad + (1 - (v - min) / span) * (H - pad * 2);

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`).join(' ');
  const area = `${line} L ${x(points.length - 1).toFixed(1)} ${H - pad} L ${x(0).toFixed(1)} ${H - pad} Z`;
  const up = values[values.length - 1] >= values[0];
  const stroke = up ? 'var(--green)' : 'var(--red)';

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} preserveAspectRatio="none" role="img">
      <defs>
        <linearGradient id="eqfill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={stroke} stopOpacity="0.22" />
          <stop offset="100%" stopColor={stroke} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill="url(#eqfill)" />
      <path d={line} fill="none" stroke={stroke} strokeWidth="2" strokeLinejoin="round" />
    </svg>
  );
}
