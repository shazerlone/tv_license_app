<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SymbolMap extends Model
{
    protected $fillable = ['copier_slave_id', 'master_symbol', 'slave_symbol'];

    public function copierSlave(): BelongsTo
    {
        return $this->belongsTo(CopierSlave::class);
    }
}
