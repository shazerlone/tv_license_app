<?php

namespace App\Console\Commands;

use App\Models\TerminalInstance;
use App\Models\TerminalStatusLog;
use App\Models\TradingAccount;
use App\Models\VpsServer;
use Illuminate\Console\Command;

/**
 * Detects dead AGENTS and dead terminals via missed heartbeats and flips them
 * offline so the dashboard reflects reality even when an agent stops reporting.
 *
 * Schedule this every minute (see routes/console.php / Kernel schedule):
 *   $schedule->command('mt5:mark-stale')->everyMinute();
 */
class MarkStaleOffline extends Command
{
    protected $signature = 'mt5:mark-stale {--terminal-grace=90 : seconds} {--server-grace=120 : seconds}';
    protected $description = 'Mark terminals/servers offline when heartbeats go stale';

    public function handle(): int
    {
        $tCut = now()->subSeconds((int) $this->option('terminal-grace'));
        $sCut = now()->subSeconds((int) $this->option('server-grace'));

        // Stale terminals -> mark disconnected + log the transition.
        $staleTerminals = TerminalInstance::whereIn('status', ['running', 'connected', 'starting', 'restarting'])
            ->where(fn ($q) => $q->whereNull('last_heartbeat_at')->orWhere('last_heartbeat_at', '<', $tCut))
            ->get();

        foreach ($staleTerminals as $instance) {
            TerminalStatusLog::create([
                'terminal_instance_id' => $instance->id,
                'trading_account_id'   => $instance->trading_account_id,
                'vps_server_id'        => $instance->vps_server_id,
                'from_status'          => $instance->status,
                'to_status'            => 'disconnected',
                'reason'               => 'heartbeat_timeout',
                'created_at'           => now(),
            ]);
            $instance->update(['status' => 'disconnected', 'mt5_connected' => false]);
            TradingAccount::whereKey($instance->trading_account_id)->update(['status' => 'disconnected']);
        }

        // Stale servers -> offline.
        $servers = VpsServer::where('status', 'online')
            ->where(fn ($q) => $q->whereNull('last_heartbeat_at')->orWhere('last_heartbeat_at', '<', $sCut))
            ->update(['status' => 'offline']);

        $this->info("Stale terminals: {$staleTerminals->count()}, servers offlined: {$servers}");

        return self::SUCCESS;
    }
}
