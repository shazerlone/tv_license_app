<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Time-series host-level health samples, one row per heartbeat per VPS.
     * Drives the CPU/RAM charts on the dashboard. Prune older than N days.
     */
    public function up(): void
    {
        Schema::create('health_metrics', function (Blueprint $table) {
            $table->id();

            $table->foreignId('vps_server_id')
                  ->constrained('vps_servers')->cascadeOnDelete();

            $table->decimal('cpu_pct', 5, 2);
            $table->unsignedInteger('ram_used_mb');
            $table->unsignedInteger('ram_total_mb');
            $table->unsignedSmallInteger('active_terminals');
            $table->unsignedInteger('disk_free_mb')->nullable();
            $table->decimal('load_avg', 6, 2)->nullable();     // agent-computed 1m avg

            $table->timestamp('sampled_at')->useCurrent();

            $table->index(['vps_server_id', 'sampled_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('health_metrics');
    }
};
