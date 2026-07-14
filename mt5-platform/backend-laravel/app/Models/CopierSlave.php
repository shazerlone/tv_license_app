<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CopierSlave extends Model
{
    protected $fillable = [
        'copier_id', 'slave_account_id', 'enabled', 'lot_mode',
        'lot_multiplier', 'fixed_lots', 'balance_multiplier', 'risk_percent',
        'min_lot', 'max_lot', 'reverse', 'copy_sl_tp', 'max_slippage_points',
    ];

    protected $casts = [
        'enabled'            => 'boolean',
        'reverse'            => 'boolean',
        'copy_sl_tp'         => 'boolean',
        'lot_multiplier'     => 'decimal:3',
        'fixed_lots'         => 'decimal:3',
        'balance_multiplier' => 'decimal:3',
        'risk_percent'       => 'decimal:3',
        'min_lot'            => 'decimal:3',
        'max_lot'            => 'decimal:3',
    ];

    public function copier(): BelongsTo
    {
        return $this->belongsTo(Copier::class);
    }

    public function slave(): BelongsTo
    {
        return $this->belongsTo(TradingAccount::class, 'slave_account_id');
    }

    public function symbolMaps(): HasMany
    {
        return $this->hasMany(SymbolMap::class);
    }

    public function copyTrades(): HasMany
    {
        return $this->hasMany(CopyTrade::class);
    }
}
