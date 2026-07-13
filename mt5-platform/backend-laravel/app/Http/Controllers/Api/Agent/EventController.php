<?php

namespace App\Http\Controllers\Api\Agent;

use App\Http\Controllers\Controller;
use App\Models\TerminalEvent;
use App\Models\VpsServer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Idempotent, at-least-once event ingest. The agent buffers events locally and
 * re-sends until it sees them in `accepted`. Dedup is by `event_uid`.
 */
class EventController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        /** @var VpsServer $server */
        $server = $request->attributes->get('vps_server');

        $data = $request->validate([
            'events'                     => ['required', 'array', 'max:200'],
            'events.*.event_uid'         => ['required', 'uuid'],
            'events.*.trading_account_id'=> ['nullable', 'integer'],
            'events.*.type'              => ['required', 'string'],
            'events.*.severity'          => ['nullable', 'in:info,warning,error,critical'],
            'events.*.message'           => ['nullable', 'string', 'max:2000'],
            'events.*.context'           => ['nullable', 'array'],
            'events.*.occurred_at'       => ['required', 'date'],
        ]);

        $accepted = [];

        foreach ($data['events'] as $e) {
            // Scope account to this server; drop foreign account references.
            $accountId = null;
            if (! empty($e['trading_account_id'])) {
                $accountId = $server->tradingAccounts()
                    ->whereKey($e['trading_account_id'])->value('id');
            }

            TerminalEvent::updateOrCreate(
                ['event_uid' => $e['event_uid']],       // idempotency key
                [
                    'vps_server_id'      => $server->id,
                    'trading_account_id' => $accountId,
                    'type'               => $e['type'],
                    'severity'           => $e['severity'] ?? 'info',
                    'message'            => $e['message'] ?? null,
                    'context'            => $e['context'] ?? null,
                    'occurred_at'        => $e['occurred_at'],
                ]
            );

            $accepted[] = $e['event_uid'];
        }

        return response()->json(['accepted' => $accepted]);
    }
}
