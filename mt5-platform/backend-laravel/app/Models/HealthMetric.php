<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HealthMetric extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'vps_server_id', 'cpu_pct', 'ram_used_mb', 'ram_total_mb',
        'active_terminals', 'disk_free_mb', 'load_avg', 'sampled_at',
    ];

    protected $casts = [
        'cpu_pct'    => 'decimal:2',
        'load_avg'   => 'decimal:2',
        'sampled_at' => 'datetime',
    ];

    public function server(): BelongsTo
    {
        return $this->belongsTo(VpsServer::class, 'vps_server_id');
    }
}
