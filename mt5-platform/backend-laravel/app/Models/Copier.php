<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Copier extends Model
{
    protected $fillable = ['master_account_id', 'name', 'enabled', 'copy_new_only'];

    protected $casts = [
        'enabled'       => 'boolean',
        'copy_new_only' => 'boolean',
    ];

    public function master(): BelongsTo
    {
        return $this->belongsTo(TradingAccount::class, 'master_account_id');
    }

    public function slaves(): HasMany
    {
        return $this->hasMany(CopierSlave::class);
    }
}
