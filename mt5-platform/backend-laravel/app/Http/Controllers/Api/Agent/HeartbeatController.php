<?php

namespace App\Http\Controllers\Api\Agent;

use App\Http\Controllers\Controller;
use App\Models\HealthMetric;
use App\Models\TerminalInstance;
use App\Models\TerminalStatusLog;
use App\Models\TradingAccount;
use App\Models\VpsServer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ingests one heartbeat from the agent: host-level metrics + a snapshot of
 * every terminal it manages. Upserts terminal rows, records a health sample,
 * and refreshes the denormalised fields the dashboard reads.
 */
class HeartbeatController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        /** @var VpsServer $server */
        $server = $request->attributes->get('vps_server');

        $data = $request->validate([
            'host'                        => ['required', 'array'],
            'host.cpu_pct'                => ['required', 'numeric', 'min:0', 'max:100'],
            'host.ram_used_mb'            => ['required', 'integer', 'min:0'],
            'host.ram_total_mb'           => ['required', 'integer', 'min:1'],
            'host.disk_free_mb'           => ['nullable', 'integer', 'min:0'],
            'host.load_avg'               => ['nullable', 'numeric'],
            'host.cpu_cores'              => ['nullable', 'integer'],
            'agent_version'               => ['nullable', 'string', 'max:32'],
            'terminals'                   => ['present', 'array'],
            'terminals.*.account_id'      => ['required', 'integer'],
            'terminals.*.status'          => ['required', 'string'],
            'terminals.*.os_pid'          => ['nullable', 'integer'],
            'terminals.*.cpu_pct'         => ['nullable', 'numeric'],
            'terminals.*.ram_mb'          => ['nullable', 'integer'],
            'terminals.*.mt5_connected'   => ['nullable', 'boolean'],
            'terminals.*.restart_count'   => ['nullable', 'integer'],
            'terminals.*.instance_key'    => ['nullable', 'string'],
            'terminals.*.data_dir'        => ['nullable', 'string'],
            'terminals.*.last_error'      => ['nullable', 'string'],
        ]);

        DB::transaction(function () use ($server, $data) {
            $activeCount = 0;

            foreach ($data['terminals'] as $t) {
                // Only touch accounts that actually belong to this server.
                $account = TradingAccount::where('id', $t['account_id'])
                    ->where('vps_server_id', $server->id)
                    ->first();
                if (! $account) {
                    continue;
                }

                $instance = TerminalInstance::firstOrNew(['trading_account_id' => $account->id]);
                $previous = $instance->status;

                $instance->fill([
                    'vps_server_id'     => $server->id,
                    'os_pid'            => $t['os_pid'] ?? null,
                    'instance_key'      => $t['instance_key'] ?? $instance->instance_key,
                    'data_dir'          => $t['data_dir'] ?? $instance->data_dir,
                    'status'            => $t['status'],
                    'cpu_pct'           => $t['cpu_pct'] ?? null,
                    'ram_mb'            => $t['ram_mb'] ?? null,
                    'mt5_connected'     => $t['mt5_connected'] ?? false,
                    'restart_count'     => $t['restart_count'] ?? $instance->restart_count,
                    'last_error'        => $t['last_error'] ?? $instance->last_error,
                    'last_heartbeat_at' => now(),
                ]);
                if (! $instance->started_at) {
                    $instance->started_at = now();
                }
                $instance->save();

                if (in_array($t['status'], ['running', 'connected'], true)) {
                    $activeCount++;
                }

                // Reflect terminal state onto the account for the dashboard.
                $account->update([
                    'status'            => $this->accountStatusFrom($t),
                    'last_connected_at' => ($t['mt5_connected'] ?? false) ? now() : $account->last_connected_at,
                ]);

                // Record transitions only (keeps the log table lean).
                if ($previous && $previous !== $t['status']) {
                    TerminalStatusLog::create([
                        'terminal_instance_id' => $instance->id,
                        'trading_account_id'   => $account->id,
                        'vps_server_id'        => $server->id,
                        'from_status'          => $previous,
                        'to_status'            => $t['status'],
                        'reason'               => 'heartbeat',
                        'cpu_pct'              => $t['cpu_pct'] ?? null,
                        'ram_mb'               => $t['ram_mb'] ?? null,
                        'created_at'           => now(),
                    ]);
                }
            }

            // Host-level time series + denormalised current values.
            HealthMetric::create([
                'vps_server_id'    => $server->id,
                'cpu_pct'          => $data['host']['cpu_pct'],
                'ram_used_mb'      => $data['host']['ram_used_mb'],
                'ram_total_mb'     => $data['host']['ram_total_mb'],
                'active_terminals' => $activeCount,
                'disk_free_mb'     => $data['host']['disk_free_mb'] ?? null,
                'load_avg'         => $data['host']['load_avg'] ?? null,
                'sampled_at'       => now(),
            ]);

            $server->update([
                'status'            => 'online',
                'last_cpu_pct'      => $data['host']['cpu_pct'],
                'last_ram_used_mb'  => $data['host']['ram_used_mb'],
                'total_ram_mb'      => $data['host']['ram_total_mb'],
                'total_cpu_cores'   => $data['host']['cpu_cores'] ?? $server->total_cpu_cores,
                'active_terminals'  => $activeCount,
                'agent_version'     => $data['agent_version'] ?? $server->agent_version,
                'last_heartbeat_at' => now(),
            ]);
        });

        return response()->json(['ok' => true, 'server_time' => now()->toIso8601String()]);
    }

    private function accountStatusFrom(array $t): string
    {
        if ($t['mt5_connected'] ?? false) {
            return 'connected';
        }

        return match ($t['status']) {
            'connected'            => 'connected',
            'running', 'starting'  => 'connecting',
            'crashed', 'errored'   => 'errored',
            'stopped'              => 'stopped',
            default                => 'disconnected',
        };
    }
}
