'use client';

import { apiFetch, setSession, clearSession, getToken, getStoredUser, AdminUser, ApiError } from './api';

/** Log in and require the admin role. Non-admins are rejected. */
export async function login(email: string, password: string): Promise<AdminUser> {
  const res = await apiFetch<{ token: string; user: AdminUser }>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  if (res.user.role !== 'admin') {
    throw new ApiError(403, 'not_admin', 'This account is not an administrator.');
  }
  setSession(res.token, res.user);
  return res.user;
}

export function logout() {
  clearSession();
}

export function isAuthed(): boolean {
  const u = getStoredUser();
  return !!getToken() && u?.role === 'admin';
}

export { getStoredUser };
