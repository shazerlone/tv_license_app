<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MT5 Manager — Sign in</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100vh; display:grid; place-items:center;
    font-family: system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    background:#0b0f17; color:#e6edf3; }
  .card { width:min(92vw,380px); background:#111826; border:1px solid #1f2a3a;
    border-radius:14px; padding:28px; box-shadow:0 10px 40px rgba(0,0,0,.4); }
  h1 { font-size:20px; margin:0 0 4px; }
  p.sub { margin:0 0 22px; color:#8b98a9; font-size:13px; }
  label { display:block; font-size:12px; color:#9fb0c3; margin:14px 0 6px; }
  input { width:100%; padding:11px 12px; border-radius:9px; border:1px solid #2a3648;
    background:#0d1420; color:#e6edf3; font-size:14px; }
  input:focus { outline:none; border-color:#3b82f6; }
  button { width:100%; margin-top:20px; padding:12px; border:0; border-radius:9px;
    background:#2563eb; color:#fff; font-weight:600; font-size:14px; cursor:pointer; }
  button:hover { background:#1d4ed8; }
  .err { background:#3b1218; border:1px solid #7f1d1d; color:#fecaca;
    padding:9px 11px; border-radius:8px; font-size:13px; margin-bottom:6px; }
  .logo { font-weight:700; letter-spacing:.5px; color:#3b82f6; margin-bottom:16px; }
</style>
</head>
<body>
  <form class="card" method="POST" action="/login">
    @csrf
    <div class="logo">▲ MT5 MANAGER</div>
    <h1>Sign in</h1>
    <p class="sub">Operator console</p>
    @if ($errors->any())
      <div class="err">{{ $errors->first() }}</div>
    @endif
    <label>Email</label>
    <input type="email" name="email" value="{{ old('email') }}" autofocus required>
    <label>Password</label>
    <input type="password" name="password" required>
    <button type="submit">Sign in</button>
  </form>
</body>
</html>
