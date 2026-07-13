<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="csrf-token" content="{{ csrf_token() }}">
<title>MT5 Manager — Dashboard</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    background:#0b0f17; color:#e6edf3; font-size:14px; }
  a { color:inherit; }
  .wrap { max-width:1200px; margin:0 auto; padding:20px; }
  header { display:flex; align-items:center; justify-content:space-between; margin-bottom:18px; }
  .logo { font-weight:700; letter-spacing:.5px; color:#3b82f6; }
  .muted { color:#8b98a9; }
  .pill { padding:2px 9px; border-radius:999px; font-size:12px; font-weight:600; }
  .btn { padding:7px 12px; border:1px solid #2a3648; background:#141d2b; color:#e6edf3;
    border-radius:8px; cursor:pointer; font-size:13px; }
  .btn:hover { background:#1b2739; }
  .btn.primary { background:#2563eb; border-color:#2563eb; color:#fff; }
  .btn.primary:hover { background:#1d4ed8; }
  .btn.danger { color:#fca5a5; border-color:#5b2020; }
  .btn.sm { padding:4px 9px; font-size:12px; }
  .card { background:#111826; border:1px solid #1f2a3a; border-radius:12px; padding:16px; }
  .grid { display:grid; gap:14px; }
  .kpis { grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); margin-bottom:16px; }
  .kpi b { display:block; font-size:28px; margin-top:4px; }
  .servers { grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); margin-bottom:16px; }
  .bar { height:6px; background:#0d1420; border-radius:4px; overflow:hidden; margin-top:6px; }
  .bar > i { display:block; height:100%; }
  table { width:100%; border-collapse:collapse; }
  th,td { text-align:left; padding:9px 10px; border-bottom:1px solid #1a2434; font-size:13px; }
  th { color:#8b98a9; font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:.4px; }
  .flash { background:#0c2a1c; border:1px solid #14532d; color:#bbf7d0;
    padding:10px 13px; border-radius:9px; margin-bottom:14px; }
  .token { background:#2a230c; border:1px solid #78591c; color:#fde68a;
    padding:12px 14px; border-radius:9px; margin-bottom:14px; word-break:break-all; }
  .cols { display:grid; grid-template-columns:1fr 1fr; gap:14px; margin-bottom:16px; }
  @media (max-width:760px){ .cols { grid-template-columns:1fr; } }
  form.inline { display:inline; }
  .field { margin-bottom:10px; }
  .field label { display:block; font-size:12px; color:#9fb0c3; margin-bottom:5px; }
  .field input, .field select { width:100%; padding:9px 10px; border-radius:8px;
    border:1px solid #2a3648; background:#0d1420; color:#e6edf3; font-size:13px; }
  .row2 { display:grid; grid-template-columns:1fr 1fr; gap:10px; }
  h3 { margin:0 0 12px; font-size:15px; }
  .dot { display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:6px; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo">▲ MT5 MANAGER</div>
    <div>
      <span class="muted" id="clock"></span>
      <form class="inline" method="POST" action="/logout">@csrf
        <button class="btn sm">Sign out</button>
      </form>
    </div>
  </header>

  @if (session('flash'))<div class="flash">{{ session('flash') }}</div>@endif
  @if (session('token'))
    <div class="token">
      <b>Agent token for {{ session('token')['name'] }}</b> — shown once. Paste into the agent's
      <code>config.yaml</code> (<code>api.token</code>):<br>
      <code>{{ session('token')['token'] }}</code>
    </div>
  @endif
  @if ($errors->any())<div class="token">{{ $errors->first() }}</div>@endif

  <!-- KPI tiles (live) -->
  <div class="grid kpis" id="kpis"></div>

  <div class="cols">
    <!-- Add account -->
    <div class="card">
      <h3>➕ Add MT5 account</h3>
      <form method="POST" action="/dashboard/accounts">@csrf
        <div class="row2">
          <div class="field"><label>MT5 login</label><input name="login" required></div>
          <div class="field"><label>Broker server</label><input name="broker_server" placeholder="ICMarketsSC-Demo" required></div>
        </div>
        <div class="row2">
          <div class="field"><label>Password</label><input name="password" type="password" required></div>
          <div class="field"><label>Password type</label>
            <select name="password_type"><option value="master">master</option><option value="investor">investor</option></select>
          </div>
        </div>
        <div class="row2">
          <div class="field"><label>Label (optional)</label><input name="label" placeholder="Client A"></div>
          <div class="field"><label>Owner (optional)</label><input name="owner"></div>
        </div>
        <button class="btn primary" type="submit">Add & auto-assign</button>
      </form>
    </div>

    <!-- Add server -->
    <div class="card">
      <h3>🖥️ Register a VPS</h3>
      <form method="POST" action="/dashboard/servers">@csrf
        <div class="field"><label>Name</label><input name="name" placeholder="vps-lon-01" required></div>
        <div class="row2">
          <div class="field"><label>IP (optional)</label><input name="ip_address" placeholder="10.0.0.5"></div>
          <div class="field"><label>Max terminals</label><input name="max_terminals" type="number" value="22"></div>
        </div>
        <button class="btn primary" type="submit">Register & get token</button>
      </form>
      <p class="muted" style="font-size:12px;margin:12px 0 0">The agent token is shown once here after you register, then paste it into that VPS's <code>config.yaml</code>.</p>
    </div>
  </div>

  <!-- Servers (live) -->
  <h3>Servers</h3>
  <div class="grid servers" id="servers"></div>

  <!-- Terminals / accounts (live) -->
  <div class="card">
    <h3>Terminals & accounts</h3>
    <div style="overflow-x:auto">
      <table>
        <thead><tr>
          <th>Login</th><th>Label</th><th>Server</th><th>Status</th>
          <th>CPU</th><th>RAM</th><th>Restarts</th><th>Actions</th>
        </tr></thead>
        <tbody id="accounts-body"></tbody>
      </table>
    </div>
  </div>
</div>

<script>
  const INIT = @json(['kpi' => $kpi, 'servers' => $servers, 'accounts' => $accounts]);
  const CSRF = document.querySelector('meta[name=csrf-token]').content;

  const statusColor = s => ({
    connected:'#22c55e', running:'#22c55e', connecting:'#f59e0b', starting:'#f59e0b',
    restarting:'#f59e0b', assigned:'#60a5fa', crashed:'#ef4444', errored:'#ef4444',
    disconnected:'#fb923c', stopped:'#6b7280', unassigned:'#6b7280', online:'#22c55e',
    offline:'#ef4444', draining:'#f59e0b', disabled:'#6b7280',
  }[s] || '#9ca3af');

  const esc = s => (s==null?'':String(s)).replace(/[&<>"]/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

  function kpiTile(label, value, color) {
    return `<div class="card kpi"><span class="muted">${label}</span><b style="color:${color||'#e6edf3'}">${value}</b></div>`;
  }

  function render(d) {
    const k = d.kpi;
    document.getElementById('kpis').innerHTML =
      kpiTile('Terminals', k.total) +
      kpiTile('Online', k.online, '#22c55e') +
      kpiTile('Offline', k.offline, '#fb923c') +
      kpiTile('Errored', k.errored, k.errored? '#ef4444':'#e6edf3') +
      kpiTile('Servers online', k.servers_online+' / '+k.servers_total) +
      kpiTile('Fleet RAM', k.fleet_ram_pct+'%', k.fleet_ram_pct>85?'#ef4444':'#e6edf3') +
      kpiTile('Unassigned', k.unassigned, k.unassigned? '#f59e0b':'#e6edf3');

    document.getElementById('servers').innerHTML = d.servers.length ? d.servers.map(s => {
      const ramPct = s.ram_total ? Math.round(s.ram_used/s.ram_total*100) : 0;
      const cpu = s.cpu ?? 0;
      return `<div class="card">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <b>${esc(s.name)}</b>
          <span class="pill" style="background:${statusColor(s.status)}22;color:${statusColor(s.status)}">
            <span class="dot" style="background:${statusColor(s.status)}"></span>${s.status}</span>
        </div>
        <div class="muted" style="margin:8px 0 2px">Terminals ${s.active}/${s.max} · last seen ${esc(s.last_seen||'never')}</div>
        <div>CPU ${cpu}% <div class="bar"><i style="width:${Math.min(cpu,100)}%;background:${cpu>s.cpu_limit?'#ef4444':'#3b82f6'}"></i></div></div>
        <div style="margin-top:8px">RAM ${s.ram_used||0}/${s.ram_total||'?'} MB
          <div class="bar"><i style="width:${ramPct}%;background:${ramPct>85?'#ef4444':'#22c55e'}"></i></div></div>
      </div>`;
    }).join('') : '<div class="card muted">No servers yet — register one above.</div>';

    document.getElementById('accounts-body').innerHTML = d.accounts.length ? d.accounts.map(a => `
      <tr>
        <td><b>${esc(a.login)}</b>${a.managed?'':' <span class="pill" style="background:#334155;color:#94a3b8;font-size:10px">discovered</span>'}<br><span class="muted" style="font-size:11px">${esc(a.broker_server)}</span></td>
        <td>${esc(a.label||'—')}</td>
        <td>${a.server ? esc(a.server) : '<span class="muted">unassigned</span>'}</td>
        <td><span class="pill" style="background:${statusColor(a.status)}22;color:${statusColor(a.status)}">
            <span class="dot" style="background:${statusColor(a.status)}"></span>${a.status}</span>
            ${a.desired==='stopped'?' <span class="muted" style="font-size:11px">(stopping)</span>':''}</td>
        <td>${a.cpu!=null?a.cpu+'%':'—'}</td>
        <td>${a.ram!=null?a.ram+' MB':'—'}</td>
        <td>${a.restarts}</td>
        <td style="white-space:nowrap">
          ${a.managed ? `
          <form class="inline" method="POST" action="/dashboard/accounts/${a.id}/restart">
            <input type="hidden" name="_token" value="${CSRF}"><button class="btn sm">↻</button></form>
          ${a.desired==='running'
            ? `<form class="inline" method="POST" action="/dashboard/accounts/${a.id}/stop"><input type="hidden" name="_token" value="${CSRF}"><button class="btn sm">■ stop</button></form>`
            : `<form class="inline" method="POST" action="/dashboard/accounts/${a.id}/start"><input type="hidden" name="_token" value="${CSRF}"><button class="btn sm">▶ start</button></form>`}` : `<span class="muted" style="font-size:11px">monitor-only</span>`}
          <form class="inline" method="POST" action="/dashboard/accounts/${a.id}" onsubmit="return confirm('Remove ${esc(a.login)} from the list?')">
            <input type="hidden" name="_token" value="${CSRF}"><input type="hidden" name="_method" value="DELETE">
            <button class="btn sm danger">✕</button></form>
        </td>
      </tr>`).join('') : '<tr><td colspan="8" class="muted">No accounts yet — add one above.</td></tr>';
  }

  function tick() {
    document.getElementById('clock').textContent = new Date().toLocaleTimeString();
  }

  render(INIT); tick();
  setInterval(tick, 1000);
  setInterval(() => fetch('/dashboard/data', {headers:{'Accept':'application/json'}})
    .then(r => r.ok ? r.json() : null).then(d => d && render(d)).catch(()=>{}), 5000);
</script>
</body>
</html>
