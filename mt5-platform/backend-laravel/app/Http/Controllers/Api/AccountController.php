<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreAccountRequest;
use App\Models\TradingAccount;
use App\Services\SchedulerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Operator-facing account management. Auth: sanctum/JWT (the web dashboard
 * or Flutter app). This is where the operator's "meta details" enter the system.
 */
class AccountController extends Controller
{
    public function __construct(private SchedulerService $scheduler) {}

    public function index(Request $request): JsonResponse
    {
        $accounts = TradingAccount::query()
            ->with(['server:id,name,status', 'terminal:id,trading_account_id,status,cpu_pct,ram_mb,mt5_connected,last_heartbeat_at'])
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('vps_server_id'), fn ($q) => $q->where('vps_server_id', $request->vps_server_id))
            ->latest()
            ->paginate(50);

        return response()->json($accounts);   // password never included ($hidden)
    }

    /**
     * Create an account from the operator's entered meta details, then let the
     * scheduler place it on the least-loaded VPS.
     */
    public function store(StoreAccountRequest $request): JsonResponse
    {
        $account = TradingAccount::create([
            'login'              => $request->login,
            'broker_server'      => $request->broker_server,
            'password_encrypted' => $request->password,   // encrypted by cast
            'password_type'      => $request->input('password_type', 'master'),
            'label'              => $request->label,
            'owner'              => $request->owner,
            'license_id'         => $request->license_id,
            'desired_state'      => 'running',
            'status'             => 'unassigned',
        ]);

        $server = $this->scheduler->assign($account);

        return response()->json([
            'account' => $account->fresh()->load('server:id,name'),
            'placed'  => (bool) $server,
            'message' => $server
                ? "Assigned to {$server->name}"
                : 'Created but fleet is at capacity — will be placed when a slot frees up.',
        ], 201);
    }

    public function show(TradingAccount $account): JsonResponse
    {
        return response()->json(
            $account->load(['server:id,name,status', 'terminal'])
        );
    }

    /** Request a restart of this account's terminal. The agent picks it up on next poll. */
    public function restart(TradingAccount $account): JsonResponse
    {
        if (! $account->terminal) {
            return response()->json(['message' => 'No live terminal to restart'], 409);
        }

        $account->terminal->update(['status' => 'restarting']);

        return response()->json(['message' => 'Restart requested', 'account_id' => $account->id]);
    }

    /** Stop (desired_state=stopped); the agent will shut the terminal down and free the slot. */
    public function stop(TradingAccount $account): JsonResponse
    {
        $account->update(['desired_state' => 'stopped']);

        return response()->json(['message' => 'Stop requested']);
    }

    /** Resume a stopped account. */
    public function start(TradingAccount $account): JsonResponse
    {
        $account->update(['desired_state' => 'running']);
        if (! $account->vps_server_id) {
            $this->scheduler->assign($account);
        }

        return response()->json(['message' => 'Start requested']);
    }

    public function destroy(TradingAccount $account): JsonResponse
    {
        $this->scheduler->release($account);
        $account->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
