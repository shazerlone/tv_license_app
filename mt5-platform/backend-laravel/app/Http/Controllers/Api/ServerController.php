<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthMetric;
use App\Models\VpsServer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Operator-facing VPS fleet management + health read APIs.
 */
class ServerController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(
            VpsServer::query()
                ->withCount(['terminalInstances as running_terminals' => fn ($q) => $q->whereIn('status', ['running', 'connected'])])
                ->orderBy('name')
                ->get()
        );
    }

    /** Register a new VPS and hand back its agent token ONCE. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'               => ['required', 'string', 'max:64', 'unique:vps_servers,name'],
            'hostname'           => ['nullable', 'string', 'max:255'],
            'ip_address'         => ['nullable', 'ip'],
            'max_terminals'      => ['nullable', 'integer', 'min:1', 'max:200'],
            'ram_soft_limit_mb'  => ['nullable', 'integer', 'min:512'],
            'cpu_soft_limit_pct' => ['nullable', 'integer', 'min:10', 'max:100'],
        ]);

        $server = VpsServer::create($data + ['agent_token_hash' => 'pending']);
        $token = $server->issueAgentToken();

        return response()->json([
            'server'      => $server->fresh(),
            'agent_token' => $token,   // shown ONCE — operator pastes into agent config.yaml
            'warning'     => 'Store this token now. It cannot be retrieved again.',
        ], 201);
    }

    public function show(VpsServer $server): JsonResponse
    {
        return response()->json(
            $server->loadCount('terminalInstances')
                   ->load(['terminalInstances:id,vps_server_id,trading_account_id,status,cpu_pct,ram_mb'])
        );
    }

    /** Time-series health for the CPU/RAM charts. */
    public function health(Request $request, VpsServer $server): JsonResponse
    {
        $since = now()->subHours((int) $request->input('hours', 6));

        $metrics = HealthMetric::where('vps_server_id', $server->id)
            ->where('sampled_at', '>=', $since)
            ->orderBy('sampled_at')
            ->get(['cpu_pct', 'ram_used_mb', 'ram_total_mb', 'active_terminals', 'sampled_at']);

        return response()->json([
            'server'  => $server->only(['id', 'name', 'status', 'last_cpu_pct', 'last_ram_used_mb', 'active_terminals', 'max_terminals']),
            'metrics' => $metrics,
        ]);
    }

    /** Put a server into drain (no new assignments) or bring it back / disable it. */
    public function setStatus(Request $request, VpsServer $server): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'in:online,draining,disabled'],
        ]);
        $server->update($data);

        return response()->json(['message' => "Server marked {$data['status']}"]);
    }

    public function rotateToken(VpsServer $server): JsonResponse
    {
        $token = $server->issueAgentToken();

        return response()->json([
            'agent_token' => $token,
            'warning'     => 'Old token is now invalid. Update the agent config and restart it.',
        ]);
    }
}
