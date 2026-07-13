<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TerminalEvent extends Model
{
    protected $fillable = [
        'event_uid', 'vps_server_id', 'trading_account_id', 'terminal_instance_id',
        'type', 'severity', 'message', 'context', 'occurred_at',
    ];

    protected $casts = [
        'context'     => 'array',
        'occurred_at' => 'datetime',
    ];

    public function server(): BelongsTo
    {
        return $this->belongsTo(VpsServer::class, 'vps_server_id');
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(TradingAccount::class, 'trading_account_id');
    }
}
