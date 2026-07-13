<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class TradingAccount extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'login', 'broker_server', 'password_encrypted', 'password_type',
        'label', 'owner', 'license_id', 'desired_state', 'vps_server_id',
        'status', 'assigned_at', 'last_connected_at',
    ];

    /**
     * `password_encrypted` uses Laravel's 'encrypted' cast: transparent
     * AES-256-GCM at rest keyed by APP_KEY. It is in $hidden so it never
     * leaks into JSON responses.
     */
    protected $casts = [
        'password_encrypted' => 'encrypted',
        'assigned_at'        => 'datetime',
        'last_connected_at'  => 'datetime',
    ];

    protected $hidden = ['password_encrypted'];

    public function server(): BelongsTo
    {
        return $this->belongsTo(VpsServer::class, 'vps_server_id');
    }

    public function terminal(): HasOne
    {
        return $this->hasOne(TerminalInstance::class);
    }

    /** Accounts that want to run but aren't placed on a VPS yet. */
    public function scopePendingPlacement($query)
    {
        return $query->where('desired_state', 'running')
                     ->whereNull('vps_server_id');
    }
}
