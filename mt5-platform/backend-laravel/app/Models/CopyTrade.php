<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CopyTrade extends Model
{
    protected $fillable = [
        'copier_slave_id', 'master_ticket', 'slave_ticket', 'master_symbol',
        'slave_symbol', 'side', 'master_volume', 'slave_volume', 'status',
        'error', 'opened_at', 'closed_at',
    ];

    protected $casts = [
        'master_volume' => 'decimal:3',
        'slave_volume'  => 'decimal:3',
        'opened_at'     => 'datetime',
        'closed_at'     => 'datetime',
    ];

    public function copierSlave(): BelongsTo
    {
        return $this->belongsTo(CopierSlave::class);
    }
}
