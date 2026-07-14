<?php

namespace App\Http\Controllers;

use App\Models\Copier;
use App\Models\CopierSlave;
use App\Models\SymbolMap;
use App\Models\TradingAccount;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Operator UI for the trade copier (the tree page). Masters fan out to slaves;
 * each slave has lot rules + symbol maps. Session-authenticated (web).
 */
class CopierController extends Controller
{
    public function index()
    {
        return view('copier', [
            'copiers'  => $this->tree(),
            'accounts' => $this->connectedAccounts(),
        ]);
    }

    /** JSON snapshot for live refresh. */
    public function data()
    {
        return response()->json([
            'copiers'  => $this->tree(),
            'accounts' => $this->connectedAccounts(),
        ]);
    }

    // ── masters ──────────────────────────────────────────────────────────────
    public function store(Request $request)
    {
        $data = $request->validate([
            'master_account_id' => [
                'required', 'integer', 'exists:trading_accounts,id',
                Rule::unique('copiers', 'master_account_id'),
            ],
            'name' => ['nullable', 'string', 'max:64'],
        ]);
        Copier::create($data);

        return back()->with('flash', 'Master added.');
    }

    public function toggle(Copier $copier)
    {
        $copier->update(['enabled' => ! $copier->enabled]);
        return back();
    }

    public function destroy(Copier $copier)
    {
        $copier->delete();
        return back()->with('flash', 'Master removed.');
    }

    // ── slaves ───────────────────────────────────────────────────────────────
    public function storeSlave(Request $request, Copier $copier)
    {
        $data = $this->validateSlave($request, $copier->id);
        $data['copier_id'] = $copier->id;
        CopierSlave::create($data);

        return back()->with('flash', 'Slave added.');
    }

    public function updateSlave(Request $request, CopierSlave $slave)
    {
        $slave->update($this->validateSlave($request, $slave->copier_id, $slave->id));
        return back()->with('flash', 'Slave updated.');
    }

    public function toggleSlave(CopierSlave $slave)
    {
        $slave->update(['enabled' => ! $slave->enabled]);
        return back();
    }

    public function destroySlave(CopierSlave $slave)
    {
        $slave->delete();
        return back()->with('flash', 'Slave removed.');
    }

    // ── symbol maps ──────────────────────────────────────────────────────────
    public function storeMap(Request $request, CopierSlave $slave)
    {
        $data = $request->validate([
            'master_symbol' => ['required', 'string', 'max:32'],
            'slave_symbol'  => ['required', 'string', 'max:32'],
        ]);
        // upsert: master symbol maps once per slave (many masters -> one slave ok)
        SymbolMap::updateOrCreate(
            ['copier_slave_id' => $slave->id, 'master_symbol' => $data['master_symbol']],
            ['slave_symbol' => $data['slave_symbol']],
        );

        return back()->with('flash', 'Mapping saved.');
    }

    public function destroyMap(SymbolMap $map)
    {
        $map->delete();
        return back();
    }

    // ── helpers ──────────────────────────────────────────────────────────────
    private function validateSlave(Request $request, int $copierId, ?int $ignoreId = null): array
    {
        return $request->validate([
            'slave_account_id' => [
                'required', 'integer', 'exists:trading_accounts,id',
                Rule::unique('copier_slaves', 'slave_account_id')
                    ->where('copier_id', $copierId)
                    ->ignore($ignoreId),
            ],
            'lot_mode'            => ['required', Rule::in(['multiplier', 'fixed', 'balance'])],
            'lot_multiplier'      => ['nullable', 'numeric', 'min:0.001', 'max:1000'],
            'fixed_lots'          => ['nullable', 'numeric', 'min:0.001', 'max:1000'],
            'balance_multiplier'  => ['nullable', 'numeric', 'min:0.001', 'max:1000'],
            'risk_percent'        => ['nullable', 'numeric', 'min:0', 'max:100'],
            'min_lot'             => ['nullable', 'numeric', 'min:0'],
            'max_lot'             => ['nullable', 'numeric', 'min:0'],
            'reverse'             => ['nullable', 'boolean'],
            'copy_sl_tp'          => ['nullable', 'boolean'],
            'max_slippage_points' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);
    }

    /** Accounts that can be picked as master/slave (managed + have a terminal). */
    private function connectedAccounts()
    {
        return TradingAccount::query()
            ->where('is_managed', true)
            ->with('terminal:id,trading_account_id,login_verified,balance,account_currency')
            ->orderBy('login')
            ->get()
            ->map(fn ($a) => [
                'id'       => $a->id,
                'login'    => $a->login,
                'label'    => $a->label,
                'server'   => $a->broker_server,
                'status'   => $a->status,
                'verified' => (bool) $a->terminal?->login_verified,
                'balance'  => $a->terminal?->balance,
                'currency' => $a->terminal?->account_currency,
            ]);
    }

    private function tree()
    {
        return Copier::query()
            ->with([
                'master:id,login,label,broker_server,status',
                'slaves.slave:id,login,label,broker_server,status',
                'slaves.symbolMaps',
            ])
            ->get()
            ->map(fn (Copier $c) => [
                'id'      => $c->id,
                'name'    => $c->name,
                'enabled' => $c->enabled,
                'master'  => $c->master ? [
                    'account_id' => $c->master->id,
                    'login'      => $c->master->login,
                    'label'      => $c->master->label,
                    'server'     => $c->master->broker_server,
                ] : null,
                'slaves' => $c->slaves->map(fn (CopierSlave $s) => [
                    'id'                 => $s->id,
                    'enabled'            => $s->enabled,
                    'account_id'         => $s->slave_account_id,
                    'login'              => $s->slave?->login,
                    'label'              => $s->slave?->label,
                    'server'             => $s->slave?->broker_server,
                    'lot_mode'           => $s->lot_mode,
                    'lot_multiplier'     => $s->lot_multiplier,
                    'fixed_lots'         => $s->fixed_lots,
                    'balance_multiplier' => $s->balance_multiplier,
                    'risk_percent'       => $s->risk_percent,
                    'reverse'            => $s->reverse,
                    'copy_sl_tp'         => $s->copy_sl_tp,
                    'maps'               => $s->symbolMaps->map(fn ($m) => [
                        'id' => $m->id, 'from' => $m->master_symbol, 'to' => $m->slave_symbol,
                    ]),
                ]),
            ]);
    }
}
