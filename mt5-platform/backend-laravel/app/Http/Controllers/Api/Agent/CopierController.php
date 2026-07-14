<?php

namespace App\Http\Controllers\Api\Agent;

use App\Http\Controllers\Controller;
use App\Models\Copier;
use App\Models\CopyTrade;
use App\Models\VpsServer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Feeds the agent's copier engine its config, and ingests the copy events it
 * produces (master_ticket <-> slave_ticket). Scoped to copiers whose MASTER
 * lives on the calling VPS.
 */
class CopierController extends Controller
{
    /** Copier config for masters running on this VPS. */
    public function index(Request $request): JsonResponse
    {
        /** @var VpsServer $server */
        $server = $request->attributes->get('vps_server');

        $copiers = Copier::query()
            ->where('enabled', true)
            ->whereHas('master', fn ($q) => $q->where('vps_server_id', $server->id))
            ->with(['master:id,login,vps_server_id',
                    'slaves' => fn ($q) => $q->where('enabled', true),
                    'slaves.slave:id,login,vps_server_id',
                    'slaves.symbolMaps'])
            ->get()
            ->map(function (Copier $c) use ($server) {
                return [
                    'copier_id'     => $c->id,
                    'copy_new_only' => $c->copy_new_only,
                    'master'        => [
                        'account_id' => $c->master->id,
                        'login'      => $c->master->login,
                    ],
                    'slaves' => $c->slaves->map(function ($s) use ($server) {
                        return [
                            'copier_slave_id'    => $s->id,
                            'account_id'         => $s->slave_account_id,
                            'login'              => $s->slave?->login,
                            'same_vps'           => (int) $s->slave?->vps_server_id === (int) $server->id,
                            'lot_mode'           => $s->lot_mode,
                            'lot_multiplier'     => (float) $s->lot_multiplier,
                            'fixed_lots'         => $s->fixed_lots !== null ? (float) $s->fixed_lots : null,
                            'balance_multiplier' => (float) $s->balance_multiplier,
                            'risk_percent'       => $s->risk_percent !== null ? (float) $s->risk_percent : null,
                            'min_lot'            => $s->min_lot !== null ? (float) $s->min_lot : null,
                            'max_lot'            => $s->max_lot !== null ? (float) $s->max_lot : null,
                            'reverse'            => (bool) $s->reverse,
                            'copy_sl_tp'         => (bool) $s->copy_sl_tp,
                            'max_slippage_points'=> $s->max_slippage_points,
                            'maps'               => $s->symbolMaps->map(fn ($m) => [
                                'from' => $m->master_symbol, 'to' => $m->slave_symbol,
                            ])->values(),
                            // Open links so the engine can rebuild state after a restart.
                            'open_trades' => CopyTrade::where('copier_slave_id', $s->id)
                                ->where('status', 'open')
                                ->get(['master_ticket', 'slave_ticket', 'slave_symbol', 'slave_volume'])
                                ->map(fn ($t) => [
                                    'master_ticket' => (int) $t->master_ticket,
                                    'slave_ticket'  => $t->slave_ticket ? (int) $t->slave_ticket : null,
                                    'slave_symbol'  => $t->slave_symbol,
                                    'slave_volume'  => (float) $t->slave_volume,
                                ])->values(),
                        ];
                    })->values(),
                ];
            });

        return response()->json(['copiers' => $copiers, 'server_time' => now()->toIso8601String()]);
    }

    /** Ingest copy open/close events (idempotent by copier_slave_id + master_ticket). */
    public function events(Request $request): JsonResponse
    {
        $data = $request->validate([
            'events'                    => ['required', 'array', 'max:200'],
            'events.*.copier_slave_id'  => ['required', 'integer'],
            'events.*.master_ticket'    => ['required', 'integer'],
            'events.*.slave_ticket'     => ['nullable', 'integer'],
            'events.*.master_symbol'    => ['nullable', 'string'],
            'events.*.slave_symbol'     => ['nullable', 'string'],
            'events.*.side'             => ['nullable', 'in:buy,sell'],
            'events.*.master_volume'    => ['nullable', 'numeric'],
            'events.*.slave_volume'     => ['nullable', 'numeric'],
            'events.*.status'           => ['required', 'in:pending,open,closed,error'],
            'events.*.error'            => ['nullable', 'string'],
        ]);

        foreach ($data['events'] as $e) {
            $attrs = [
                'status'        => $e['status'],
                'slave_ticket'  => $e['slave_ticket'] ?? null,
                'error'         => $e['error'] ?? null,
            ];
            if (($e['status'] ?? null) === 'open')   { $attrs['opened_at'] = now(); }
            if (($e['status'] ?? null) === 'closed') { $attrs['closed_at'] = now(); }

            CopyTrade::updateOrCreate(
                ['copier_slave_id' => $e['copier_slave_id'], 'master_ticket' => $e['master_ticket']],
                array_merge($attrs, array_filter([
                    'master_symbol' => $e['master_symbol'] ?? null,
                    'slave_symbol'  => $e['slave_symbol'] ?? null,
                    'side'          => $e['side'] ?? null,
                    'master_volume' => $e['master_volume'] ?? null,
                    'slave_volume'  => $e['slave_volume'] ?? null,
                ], fn ($v) => $v !== null)),
            );
        }

        return response()->json(['ok' => true, 'count' => count($data['events'])]);
    }
}
