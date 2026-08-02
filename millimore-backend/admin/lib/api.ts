// Thin fetch layer over the Millimore backend. All calls are client-side; the
// JWT lives in localStorage. Base URL comes from NEXT_PUBLIC_API_BASE_URL.

// Default is the relative, same-origin `/v1` — so when the backend serves this
// static build at its own root (single-origin deploy), no config is needed.
// For split local dev (admin on :3001, API on :3000) set
// NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/v1 in .env.local.
export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, '') || '/v1';

const TOKEN_KEY = 'millimore_admin_token';
const USER_KEY = 'millimore_admin_user';

export interface AdminUser {
  id: string;
  name: string;
  username: string;
  email: string | null;
  phone: string | null;
  photoUrl: string | null;
  role: 'follower' | 'creator' | 'admin';
  creatorStatus: 'none' | 'pending' | 'approved' | 'rejected' | 'suspended';
  residenceIso: string | null;
  residenceCountry: string | null;
  market: string | null;
  platform: string | null;
  createdAt: string;
  banned: boolean;
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

export function getStoredUser(): AdminUser | null {
  if (typeof window === 'undefined') return null;
  const raw = window.localStorage.getItem(USER_KEY);
  return raw ? (JSON.parse(raw) as AdminUser) : null;
}

export function setSession(token: string, user: AdminUser) {
  window.localStorage.setItem(TOKEN_KEY, token);
  window.localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearSession() {
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(USER_KEY);
}

export interface Trader {
  id: string;
  name: string;
  username: string;
  photoUrl: string | null;
  isVerified: boolean;
  isLive: boolean;
  returnPercent: number;
  returnDays: number;
  followers: number;
  copiers: number;
  aum: number;
  winRate: number;
  maxDrawdown: number;
  totalTrades: number;
  category: string;
  tags: string[];
  bio: string | null;
}

export interface Post {
  id: string;
  trader: Trader;
  type: string;
  content: string;
  pair: string | null;
  title: string | null;
  points: string[];
  likes: number;
  comments: number;
  createdAt: string;
  isLiked: boolean;
  saved: boolean;
}

export interface PublicTrade {
  id: string;
  pair: string;
  isBuy: boolean;
  status: string;
  entryPrice: number;
  exitPrice: number | null;
  pnlAmount: number;
  pnlPercent: number;
  lots: number;
  openedAt: string;
  closedAt: string | null;
}

export interface EquityPoint {
  t: string;
  value: number;
}

/** GET /admin/metrics (contract §6). */
export interface AdminMetrics {
  dau: number;
  mau: number;
  liveNow: number;
  streamsToday: number;
  totalUsers: number;
  creators: number;
  gmv: number;
  copyVolume: number;
  depositsTotal: number;
  walletLiabilities: number;
  platformRevenue: number;
  pendingPayouts: number;
  pendingPayoutAmount: number;
  errors24h: number;
  uptime: number;
}

/** A withdrawal request row from GET /admin/payouts. */
export interface AdminPayout {
  id: string;
  userId: string;
  amount: number;
  currency: string;
  status: 'pending' | 'approved' | 'rejected' | 'paid';
  method: string | null;
  note: string | null;
  reason: string | null;
  createdAt: string;
  decidedAt: string | null;
  requester: { id: string; name: string; username: string; email?: string | null };
}

/** Error carrying the contract's { code, message }. */
export class ApiError extends Error {
  code: string;
  status: number;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });

  if (res.status === 204) return undefined as T;

  const text = await res.text();
  const body = text ? JSON.parse(text) : null;

  if (!res.ok) {
    const err = body?.error ?? {};
    throw new ApiError(res.status, err.code ?? 'error', err.message ?? res.statusText);
  }
  return body as T;
}
