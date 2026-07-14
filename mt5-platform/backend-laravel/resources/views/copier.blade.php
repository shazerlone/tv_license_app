<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MT5 Manager — Copier</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    background:#0b0f17; color:#e6edf3; font-size:14px; }
  a { color:#60a5fa; text-decoration:none; }
  .wrap { max-width:1100px; margin:0 auto; padding:20px; }
  header { display:flex; align-items:center; justify-content:space-between; margin-bottom:18px; }
  .logo { font-weight:700; letter-spacing:.5px; color:#3b82f6; }
  .muted { color:#8b98a9; }
  .btn { padding:7px 12px; border:1px solid #2a3648; background:#141d2b; color:#e6edf3;
    border-radius:8px; cursor:pointer; font-size:13px; }
  .btn:hover { background:#1b2739; }
  .btn.primary { background:#2563eb; border-color:#2563eb; color:#fff; }
  .btn.sm { padding:4px 9px; font-size:12px; }
  .btn.danger { color:#fca5a5; border-color:#5b2020; }
  .card { background:#111826; border:1px solid #1f2a3a; border-radius:12px; padding:16px; margin-bottom:14px; }
  .flash { background:#0c2a1c; border:1px solid #14532d; color:#bbf7d0; padding:10px 13px; border-radius:9px; margin-bottom:14px; }
  .err { background:#3b1218; border:1px solid #7f1d1d; color:#fecaca; padding:9px 11px; border-radius:8px; margin-bottom:12px; }
  input, select { padding:8px 9px; border-radius:8px; border:1px solid #2a3648; background:#0d1420; color:#e6edf3; font-size:13px; }
  label { font-size:11px; color:#9fb0c3; display:block; margin-bottom:3px; }
  form.inline { display:inline; }
  .row { display:flex; gap:8px; flex-wrap:wrap; align-items:flex-end; }
  .pill { padding:2px 9px; border-radius:999px; font-size:11px; font-weight:600; }
  .master { border-left:3px solid #3b82f6; }
  .slave { background:#0d1524; border:1px solid #1c2740; border-radius:10px; padding:12px; margin:10px 0 0 22px; }
  .maps { margin-top:8px; }
  .maptag { display:inline-flex; align-items:center; gap:6px; background:#182338; border:1px solid #263352;
    border-radius:6px; padding:3px 8px; margin:3px 4px 0 0; font-size:12px; }
  h3 { margin:0 0 12px; font-size:15px; }
  .on { background:#0c2a1c; color:#22c55e; } .off { background:#2a1212; color:#f87171; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo">▲ MT5 MANAGER · <span style="color:#e6edf3">Copier</span></div>
    <div>
      <a href="/dashboard" class="btn sm">← Dashboard</a>
      <form class="inline" method="POST" action="/logout">@csrf<button class="btn sm">Sign out</button></form>
    </div>
  </header>

  @if (session('flash'))<div class="flash">{{ session('flash') }}</div>@endif
  @if ($errors->any())<div class="err">{{ $errors->first() }}</div>@endif

  {{-- Add master --}}
  <div class="card">
    <h3>➕ Add master</h3>
    <form method="POST" action="/copier" class="row">@csrf
      <div>
        <label>Master account</label>
        <select name="master_account_id" required>
          <option value="">— choose a connected account —</option>
          @foreach ($accounts as $a)
            <option value="{{ $a['id'] }}">{{ $a['login'] }} · {{ $a['server'] }}{{ $a['label'] ? ' · '.$a['label'] : '' }}{{ $a['verified'] ? ' ✓' : '' }}</option>
          @endforeach
        </select>
      </div>
      <div><label>Name (optional)</label><input name="name" placeholder="e.g. Century master"></div>
      <button class="btn primary" type="submit">Add master</button>
    </form>
  </div>

  {{-- Tree --}}
  @forelse ($copiers as $c)
    <div class="card master">
      <div class="row" style="justify-content:space-between">
        <div>
          <span class="pill {{ $c['enabled'] ? 'on' : 'off' }}">{{ $c['enabled'] ? 'ON' : 'OFF' }}</span>
          <b style="margin-left:6px">MASTER</b>
          @if ($c['master'])
            {{ $c['master']['login'] }} <span class="muted">· {{ $c['master']['server'] }}</span>
            @if ($c['name'])<span class="muted"> · {{ $c['name'] }}</span>@endif
          @else <span class="muted">(master account missing)</span>@endif
        </div>
        <div>
          <form class="inline" method="POST" action="/copier/{{ $c['id'] }}/toggle">@csrf<button class="btn sm">{{ $c['enabled'] ? 'Disable' : 'Enable' }}</button></form>
          <form class="inline" method="POST" action="/copier/{{ $c['id'] }}" onsubmit="return confirm('Remove this master and all its slaves?')">@csrf @method('DELETE')<button class="btn sm danger">✕ master</button></form>
        </div>
      </div>

      {{-- Slaves --}}
      @foreach ($c['slaves'] as $s)
        <div class="slave">
          <div class="row" style="justify-content:space-between">
            <div>
              <span class="pill {{ $s['enabled'] ? 'on' : 'off' }}">{{ $s['enabled'] ? 'ON' : 'OFF' }}</span>
              <b style="margin-left:6px">SLAVE</b> {{ $s['login'] }} <span class="muted">· {{ $s['server'] }}</span>
            </div>
            <div>
              <form class="inline" method="POST" action="/copier/slaves/{{ $s['id'] }}/toggle">@csrf<button class="btn sm">{{ $s['enabled'] ? 'Disable' : 'Enable' }}</button></form>
              <form class="inline" method="POST" action="/copier/slaves/{{ $s['id'] }}" onsubmit="return confirm('Remove this slave?')">@csrf @method('DELETE')<button class="btn sm danger">✕</button></form>
            </div>
          </div>

          {{-- Lot / risk settings --}}
          <form method="POST" action="/copier/slaves/{{ $s['id'] }}" class="row" style="margin-top:10px">@csrf @method('PUT')
            <div><label>Lot mode</label>
              <select name="lot_mode">
                @foreach (['multiplier'=>'Lot multiplier','fixed'=>'Fixed lots','balance'=>'Balance multiplier'] as $v=>$t)
                  <option value="{{ $v }}" @selected($s['lot_mode']===$v)>{{ $t }}</option>
                @endforeach
              </select>
            </div>
            <div style="width:90px"><label>Lot ×</label><input name="lot_multiplier" type="number" step="0.001" value="{{ $s['lot_multiplier'] }}"></div>
            <div style="width:90px"><label>Fixed lots</label><input name="fixed_lots" type="number" step="0.001" value="{{ $s['fixed_lots'] }}"></div>
            <div style="width:100px"><label>Balance ×</label><input name="balance_multiplier" type="number" step="0.001" value="{{ $s['balance_multiplier'] }}"></div>
            <div style="width:90px"><label>Risk %</label><input name="risk_percent" type="number" step="0.01" value="{{ $s['risk_percent'] }}"></div>
            <div><label>Reverse</label><input type="hidden" name="reverse" value="0"><input type="checkbox" name="reverse" value="1" @checked($s['reverse'])></div>
            <div><label>Copy SL/TP</label><input type="hidden" name="copy_sl_tp" value="0"><input type="checkbox" name="copy_sl_tp" value="1" @checked($s['copy_sl_tp'])></div>
            <button class="btn sm" type="submit">Save</button>
          </form>

          {{-- Symbol maps --}}
          <div class="maps">
            <label>Symbol mapping (master → slave · many masters may point to one slave symbol)</label>
            @foreach ($s['maps'] as $m)
              <span class="maptag">{{ $m['from'] }} → <b>{{ $m['to'] }}</b>
                <form class="inline" method="POST" action="/copier/maps/{{ $m['id'] }}">@csrf @method('DELETE')<button class="btn sm danger" style="padding:0 5px">✕</button></form>
              </span>
            @endforeach
            <form method="POST" action="/copier/slaves/{{ $s['id'] }}/maps" class="row" style="margin-top:8px">@csrf
              <div style="width:150px"><input name="master_symbol" placeholder="master e.g. GOLD_Cash" required></div>
              <div>→</div>
              <div style="width:150px"><input name="slave_symbol" placeholder="slave e.g. xauusdc" required></div>
              <button class="btn sm" type="submit">＋ Add mapping</button>
            </form>
          </div>
        </div>
      @endforeach

      {{-- Add slave --}}
      <form method="POST" action="/copier/{{ $c['id'] }}/slaves" class="row" style="margin:12px 0 0 22px">@csrf
        <div>
          <label>Add slave account</label>
          <select name="slave_account_id" required>
            <option value="">— choose account —</option>
            @foreach ($accounts as $a)
              @if (! $c['master'] || $a['id'] !== $c['master']['account_id'])
                <option value="{{ $a['id'] }}">{{ $a['login'] }} · {{ $a['server'] }}{{ $a['verified'] ? ' ✓' : '' }}</option>
              @endif
            @endforeach
          </select>
        </div>
        <div><label>Lot mode</label>
          <select name="lot_mode"><option value="multiplier">Lot multiplier</option><option value="fixed">Fixed lots</option><option value="balance">Balance multiplier</option></select>
        </div>
        <div style="width:90px"><label>Lot ×</label><input name="lot_multiplier" type="number" step="0.001" value="1"></div>
        <button class="btn primary" type="submit">＋ Add slave</button>
      </form>
    </div>
  @empty
    <div class="card muted">No copiers yet — add a master above, then add slaves under it.</div>
  @endforelse
</div>
</body>
</html>
