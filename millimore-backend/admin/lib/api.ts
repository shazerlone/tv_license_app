// Thin fetch layer over the Millimore backend. All calls are client-side; the
// JWT lives in localStorage. Base URL comes from NEXT_PUBLIC_API_BASE_URL.

export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, '') || 'http://localhost:3000/v1';

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
