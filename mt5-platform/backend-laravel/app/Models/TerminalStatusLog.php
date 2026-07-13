<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TerminalStatusLog extends Model
{
    public $timestamps = false;   // only created_at, set by DB default

    protected $fillable = [
        'terminal_instance_id', 'trading_account_id', 'vps_server_id',
        'from_status', 'to_status', 'reason', 'cpu_pct', 'ram_mb', 'created_at',
    ];

    protected $casts = ['created_at' => 'datetime'];

    public function terminal(): BelongsTo
    {
        return $this->belongsTo(TerminalInstance::class, 'terminal_instance_id');
    }
}
