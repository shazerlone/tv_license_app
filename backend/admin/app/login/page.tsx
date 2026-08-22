'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { login, isAuthed } from '../../lib/auth';
import { API_BASE } from '../../lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@millimore.app');
  const [password, setPassword] = useState('');
  const [twofaCode, setTwofaCode] = useState('');
  const [needs2fa, setNeeds2fa] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (isAuthed()) router.replace('/');
  }, [router]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await login(email, password, needs2fa ? twofaCode : undefined);
      router.replace('/');
    } catch (err: any) {
      if (err.code === 'twofa_required' || err.code === 'twofa_invalid') {
        setNeeds2fa(true);
        setError(err.code === 'twofa_invalid' ? 'Invalid code, try again.' : null);
      } else {
        setError(err.message || 'Login failed');
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={onSubmit}>
        <div className="login-brand">
          milli<b>more</b>
        </div>
        <p className="login-sub">Sign in to the admin console</p>

        {error && <div className="error">{error}</div>}

        <div className="field">
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="username"
            placeholder="you@millimore.app"
            required
          />
        </div>
        <div className="field">
          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            placeholder="••••••••"
            required
          />
        </div>
        {needs2fa && (
          <div className="field">
            <label>2FA code</label>
            <input
              type="text"
              value={twofaCode}
              onChange={(e) => setTwofaCode(e.target.value)}
              autoComplete="one-time-code"
              inputMode="numeric"
              placeholder="6-digit code or backup code"
              autoFocus
              required
            />
          </div>
        )}
        <button className="btn" type="submit" disabled={busy}>
          {busy ? 'Signing in…' : needs2fa ? 'Verify & sign in' : 'Sign in'}
        </button>

        <div className="login-foot">
          Administrator access only · <span className="mono">{API_BASE}</span>
        </div>
      </form>
    </div>
  );
}
