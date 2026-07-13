<?php

namespace App\Http\Controllers;

use App\Models\TerminalInstance;
use App\Models\TradingAccount;
use App\Models\VpsServer;
use App\Services\SchedulerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

/**
 * Session-authenticated web dashboard (Blade). This is the operator UI where MT5
 * "meta details" are entered. It reuses the same models + SchedulerService as the
 * JSON API, so the web and agent sides stay consistent.
 */
class DashboardController extends Controller
{
    public function __construct(private SchedulerService $scheduler) {}

    // ── auth ─────────────────────────────────────────────────────────────────
    public function showLogin()
    {
        return Auth::check() ? redirect('/dashboard') : view('login');
    }

    public function login(Request $request)
    {
        $creds = $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required'],
        ]);

        if (! Auth::attempt($creds, $request->boolean('remember'))) {
            return back()->withErrors(['email' => 'Invalid credentials'])->onlyInput('email');
        }

        $request->session()->regenerate();
        return redirect()->intended('/dashboard');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect('/login');
    }

    // ── views ────────────────────────────────────────────────────────────────
    public function index()
    {
        return view('dashboard', [
            'kpi'      => $this->kpis(),
            'servers'  => $this->servers(),
            'accounts' => $this->accounts(),
        ]);
    }

    /** JSON snapshot for the 5s live poll. */
    public function data()
    {
        return response()->json([
            'kpi'      => $this->kpis(),
            'servers'  => $this->servers(),
            'accounts' => $this->accounts(),
            'ts'       => now()->toDateTimeString(),
        ]);
    }

    // ── operator actions ─────────────────────────────────────────────────────
    public function storeAccount(Request $request)
    {
        $data = $request->validate([
            'login'         => [
                'required', 'string', 'max:32',
                Rule::unique('trading_accounts', 'login')
                    ->where(fn ($q) => $q->where('broker_server', $request->broker_server)),
            ],
            'broker_server' => ['required', 'string', 'max:128'],
            'password'      => ['required', 'string', 'min:4', 'max:128'],
            'password_type' => ['nullable', Rule::in(['investor', 'master'])],
            'label'         => ['nullable', 'string', 'max:128'],
            'owner'         => ['nullable', 'string', 'max:128'],
        ], [], ['login' => 'MT5 login']);

        $account = TradingAccount::create([
            'login'              => $data['login'],
            'broker_server'      => $data['broker_server'],
            'password_encrypted' => $data['password'],
            'password_type'      => $data['password_type'] ?? 'master',
            'label'              => $data['label'] ?? null,
            'owner'              => $data['owner'] ?? null,
            'desired_state'      => 'running',
            'status'             => 'unassigned',
        ]);

        $server = $this->scheduler->assign($account);

        return redirect('/dashboard')->with('flash', $server
            ? "Account {$account->login} added and assigned to {$server->name}."
            : "Account {$account->login} added, but the fleet is at capacity — it will be placed when a slot frees up.");
    }

    public function restart(TradingAccount $account)
    {
        if ($account->terminal) {
            $account->terminal->update(['status' => 'restarting']);
            return back()->with('flash', "Restart requested for {$account->login}.");
        }
        return back()->with('flash', "No live terminal for {$account->login}.");
    }

    public function stop(TradingAccount $account)
    {
        $account->update(['desired_state' => 'stopped']);
        return back()->with('flash', "Stop requested for {$account->login}.");
    }

    public function start(TradingAccount $account)
    {
        $account->update(['desired_state' => 'running']);
        if (! $account->vps_server_id) {
            $this->scheduler->assign($account);
        }
        return back()->with('flash', "Start requested for {$account->login}.");
    }

    public function destroy(TradingAccount $account)
    {
        $this->scheduler->release($account);
        $account->delete();
        return back()->with('flash', "Account {$account->login} deleted.");
    }

    public function storeServer(Request $request)
    {
        $data = $request->validate([
            'name'          => ['required', 'string', 'max:64', 'unique:vps_servers,name'],
            'ip_address'    => ['nullable', 'ip'],
            'max_terminals' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $server = VpsServer::create($data + ['agent_token_hash' => 'pending']);
        $token = $server->issueAgentToken();

        // Token is shown once via flash — operator pastes it into the agent config.
        return redirect('/dashboard')->with('token', [
            'name'  => $server->name,
            'token' => $token,
        ]);
    }

    // ── data builders ────────────────────────────────────────────────────────
    private function kpis(): array
    {
        $byStatus = TerminalInstance::query()
            ->selectRaw('status, count(*) as c')->groupBy('status')->pluck('c', 'status');

        $online  = ($byStatus['running'] ?? 0) + ($byStatus['connected'] ?? 0);
        $offline = ($byStatus['disconnected'] ?? 0) + ($byStatus['crashed'] ?? 0) + ($byStatus['stopped'] ?? 0);
        $errored = $byStatus['errored'] ?? 0;

        $ramTotal = (int) VpsServer::sum('total_ram_mb');
        $ramUsed  = (int) VpsServer::sum('last_ram_used_mb');

        return [
            'total'          => (int) $byStatus->sum(),
            'online'         => $online,
            'offline'        => $offline,
            'errored'        => $errored,
            'servers_online' => VpsServer::where('status', 'online')->count(),
            'servers_total'  => VpsServer::count(),
            'fleet_ram_pct'  => $ramTotal > 0 ? round($ramUsed / $ramTotal * 100) : 0,
            'unassigned'     => TradingAccount::whereNull('vps_server_id')->where('desired_state', 'running')->count(),
        ];
    }

    private function servers()
    {
        return VpsServer::orderBy('name')->get()->map(fn ($s) => [
            'id'            => $s->id,
            'name'          => $s->name,
            'status'        => $s->status,
            'active'        => $s->active_terminals,
            'max'           => $s->max_terminals,
            'cpu'           => $s->last_cpu_pct,
            'ram_used'      => $s->last_ram_used_mb,
            'ram_total'     => $s->total_ram_mb,
            'cpu_limit'     => $s->cpu_soft_limit_pct,
            'ram_limit'     => $s->ram_soft_limit_mb,
            'last_seen'     => optional($s->last_heartbeat_at)->diffForHumans(),
        ]);
    }

    private function accounts()
    {
        return TradingAccount::with(['server:id,name', 'terminal'])
            ->orderByDesc('id')->get()->map(fn ($a) => [
                'id'            => $a->id,
                'login'         => $a->login,
                'label'         => $a->label,
                'broker_server' => $a->broker_server,
                'server'        => $a->server?->name,
                'status'        => $a->status,
                'desired'       => $a->desired_state,
                'managed'       => (bool) $a->is_managed,
                'cpu'           => $a->terminal?->cpu_pct,
                'ram'           => $a->terminal?->ram_mb,
                'connected'     => (bool) $a->terminal?->mt5_connected,
                'restarts'      => $a->terminal?->restart_count ?? 0,
            ]);
    }
}
