<?php

namespace App\Http\Controllers\Api\Agent;

use App\Http\Controllers\Controller;
use App\Models\VpsServer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The agent's reconciliation source of truth. Returns the DESIRED state for
 * this VPS only: which accounts should be running here, with the credentials
 * and per-account action the agent must apply.
 *
 * SECURITY: this is the one endpoint that returns decrypted MT5 passwords.
 * It is HTTPS-only, agent-token scoped to a single VPS, and rate-limited.
 * The agent must treat the response as secret (write to ACL-locked files, no logs).
 */
class AssignmentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var VpsServer $server */
        $server = $request->attributes->get('vps_server');

        $accounts = $server->tradingAccounts()
            ->where('is_managed', true)   // never touch discovered/unmanaged terminals
            ->with('terminal:id,trading_account_id,status,instance_key')
            ->get()
            ->map(function ($account) {
                return [
                    'account_id'    => $account->id,
                    'login'         => $account->login,
                    'broker_server' => $account->broker_server,
                    'password'      => $account->password_encrypted,   // decrypted by cast
                    'password_type' => $account->password_type,
                    'action'        => $this->resolveAction($account),
                    'instance_key'  => $account->terminal?->instance_key ?? (string) $account->login,
                ];
            });

        return response()->json([
            'server' => [
                'id'                 => $server->id,
                'name'               => $server->name,
                'max_terminals'      => $server->max_terminals,
                'ram_soft_limit_mb'  => $server->ram_soft_limit_mb,
                'cpu_soft_limit_pct' => $server->cpu_soft_limit_pct,
                'status'             => $server->status,
            ],
            'assignments' => $accounts,
            'server_time' => now()->toIso8601String(),
        ]);
    }

    /**
     * Per-account instruction the agent obeys:
     *   stop     -> desired_state is stopped, tear the terminal down
     *   restart  -> operator asked for a restart (terminal marked 'restarting')
     *   run      -> ensure a healthy terminal is running (default)
     */
    private function resolveAction($account): string
    {
        if ($account->desired_state === 'stopped') {
            return 'stop';
        }
        if ($account->terminal && $account->terminal->status === 'restarting') {
            return 'restart';
        }

        return 'run';
    }
}
