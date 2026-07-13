<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class VpsServer extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'hostname', 'ip_address', 'agent_token_hash',
        'max_terminals', 'ram_soft_limit_mb', 'cpu_soft_limit_pct',
        'total_ram_mb', 'total_cpu_cores', 'last_cpu_pct', 'last_ram_used_mb',
        'active_terminals', 'status', 'last_heartbeat_at', 'agent_version',
    ];

    protected $hidden = ['agent_token_hash'];

    protected $casts = [
        'last_heartbeat_at' => 'datetime',
        'last_cpu_pct'      => 'decimal:2',
    ];

    public function tradingAccounts(): HasMany
    {
        return $this->hasMany(TradingAccount::class);
    }

    public function terminalInstances(): HasMany
    {
        return $this->hasMany(TerminalInstance::class);
    }

    public function healthMetrics(): HasMany
    {
        return $this->hasMany(HealthMetric::class);
    }

    /**
     * Generate a fresh agent token, store its hash, return the RAW token.
     * The raw token is shown to the operator once and never persisted.
     */
    public function issueAgentToken(): string
    {
        $raw = 'vps_'.Str::random(48);
        $this->agent_token_hash = hash('sha256', $raw);
        $this->save();

        return $raw;
    }

    public static function findByAgentToken(string $raw): ?self
    {
        return static::where('agent_token_hash', hash('sha256', $raw))->first();
    }

    /** Spare terminal slots given the hard count cap. */
    public function freeSlots(): int
    {
        return max(0, $this->max_terminals - $this->active_terminals);
    }

    /** True if the box has room by count AND is under its soft resource ceilings. */
    public function hasCapacity(): bool
    {
        if ($this->status !== 'online' || $this->freeSlots() < 1) {
            return false;
        }
        if ($this->last_ram_used_mb !== null && $this->last_ram_used_mb >= $this->ram_soft_limit_mb) {
            return false;
        }
        if ($this->last_cpu_pct !== null && $this->last_cpu_pct >= $this->cpu_soft_limit_pct) {
            return false;
        }

        return true;
    }
}
