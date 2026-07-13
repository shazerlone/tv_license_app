<?php

namespace App\Services;

use App\Models\TradingAccount;
use App\Models\VpsServer;
use Illuminate\Support\Facades\DB;

/**
 * Resource-aware placement (Phase 6) + horizontal scaling (Phase 7).
 *
 * The scheduler is the ONLY thing that writes `trading_accounts.vps_server_id`.
 * It picks the least-loaded server that still has capacity, using a row lock so
 * two concurrent assign requests can't both fill the last slot on a box.
 */
class SchedulerService
{
    /**
     * Assign one account to the best available server.
     *
     * @return VpsServer|null  the chosen server, or null if the whole fleet is full.
     */
    public function assign(TradingAccount $account): ?VpsServer
    {
        return DB::transaction(function () use ($account) {
            $server = $this->pickLeastLoadedServer();

            if (! $server) {
                return null;   // caller surfaces "fleet at capacity"
            }

            $account->update([
                'vps_server_id' => $server->id,
                'status'        => 'assigned',
                'assigned_at'   => now(),
            ]);

            // Reserve the slot immediately so the next assign in this burst sees it taken.
            $server->increment('active_terminals');

            return $server;
        });
    }

    /**
     * Least-loaded = online + under all soft ceilings, ordered by load ratio
     * (active/max) ascending, then by absolute free RAM. Locks candidate rows
     * FOR UPDATE to avoid double-filling under concurrency.
     */
    public function pickLeastLoadedServer(): ?VpsServer
    {
        $candidates = VpsServer::query()
            ->where('status', 'online')
            ->whereColumn('active_terminals', '<', 'max_terminals')
            ->lockForUpdate()
            ->get();

        return $candidates
            ->filter(fn (VpsServer $s) => $s->hasCapacity())
            ->sortBy(fn (VpsServer $s) => [
                $s->active_terminals / max(1, $s->max_terminals),   // fill ratio
                $s->last_ram_used_mb ?? 0,                          // tiebreak: less RAM used
            ])
            ->first();
    }

    /**
     * Place every account that wants to run but has no server yet.
     * Called after account creation and by a periodic rebalance job.
     *
     * @return array{placed:int, unplaced:int}
     */
    public function placePending(): array
    {
        $placed = 0;
        $unplaced = 0;

        TradingAccount::pendingPlacement()->orderBy('created_at')->each(
            function (TradingAccount $account) use (&$placed, &$unplaced) {
                $this->assign($account) ? $placed++ : $unplaced++;
            }
        );

        return ['placed' => $placed, 'unplaced' => $unplaced];
    }

    /**
     * Release an account from its server (unassign / stop).
     * Frees the reserved slot so the scheduler can reuse it.
     */
    public function release(TradingAccount $account): void
    {
        DB::transaction(function () use ($account) {
            if ($account->vps_server_id) {
                VpsServer::where('id', $account->vps_server_id)
                    ->where('active_terminals', '>', 0)
                    ->decrement('active_terminals');
            }

            $account->update([
                'vps_server_id' => null,
                'status'        => 'unassigned',
                'assigned_at'   => null,
            ]);
        });
    }
}
