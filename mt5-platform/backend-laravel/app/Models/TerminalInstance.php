<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TerminalInstance extends Model
{
    use HasFactory;

    protected $fillable = [
        'trading_account_id', 'vps_server_id', 'os_pid', 'data_dir', 'instance_key',
        'status', 'cpu_pct', 'ram_mb', 'mt5_connected', 'restart_count',
        'last_restart_at', 'last_error', 'started_at', 'last_heartbeat_at',
        'login_verified', 'balance', 'equity', 'profit', 'open_trades',
        'account_currency', 'leverage',
    ];

    protected $casts = [
        'mt5_connected'    => 'boolean',
        'login_verified'   => 'boolean',
        'cpu_pct'          => 'decimal:2',
        'balance'          => 'decimal:2',
        'equity'           => 'decimal:2',
        'profit'           => 'decimal:2',
        'last_restart_at'  => 'datetime',
        'started_at'       => 'datetime',
        'last_heartbeat_at'=> 'datetime',
    ];

    public function account(): BelongsTo
    {
        return $this->belongsTo(TradingAccount::class, 'trading_account_id');
    }

    public function server(): BelongsTo
    {
        return $this->belongsTo(VpsServer::class, 'vps_server_id');
    }

    public function statusLogs(): HasMany
    {
        return $this->hasMany(TerminalStatusLog::class);
    }

    public function isHealthy(): bool
    {
        return in_array($this->status, ['running', 'connected'], true);
    }
}
