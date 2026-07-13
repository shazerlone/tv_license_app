<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vps_servers', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();                 // "vps-lon-01"
            $table->string('hostname')->nullable();            // informational
            $table->ipAddress('ip_address')->nullable();

            // Agent authentication: we store only a SHA-256 hash of the token.
            // The raw token is shown to the operator once at creation time.
            $table->string('agent_token_hash', 64)->unique();

            // Capacity / resource ceilings used by the scheduler (Phase 6/7).
            $table->unsignedSmallInteger('max_terminals')->default(22);
            $table->unsignedInteger('ram_soft_limit_mb')->default(6500);   // leave OS headroom on 8GB
            $table->unsignedTinyInteger('cpu_soft_limit_pct')->default(85);
            $table->unsignedSmallInteger('total_ram_mb')->nullable();      // reported by agent
            $table->unsignedTinyInteger('total_cpu_cores')->nullable();

            // Last observed host-level metrics (denormalised for fast dashboard reads).
            $table->decimal('last_cpu_pct', 5, 2)->nullable();
            $table->unsignedInteger('last_ram_used_mb')->nullable();
            $table->unsignedSmallInteger('active_terminals')->default(0);

            // Lifecycle.
            $table->enum('status', ['online', 'offline', 'draining', 'disabled'])
                  ->default('offline');
            $table->timestamp('last_heartbeat_at')->nullable();
            $table->string('agent_version')->nullable();

            $table->timestamps();

            $table->index(['status', 'active_terminals']);   // scheduler picks least-loaded online box
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vps_servers');
    }
};
