<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Append-only history of terminal status transitions. Powers the timeline
     * on the dashboard and the audit trail. Keep it lean and prune with a
     * scheduled job (see DEPLOYMENT.md) since it grows fast.
     */
    public function up(): void
    {
        Schema::create('terminal_status_logs', function (Blueprint $table) {
            $table->id();

            $table->foreignId('terminal_instance_id')->nullable()
                  ->constrained('terminal_instances')->cascadeOnDelete();
            $table->foreignId('trading_account_id')->nullable()
                  ->constrained('trading_accounts')->nullOnDelete();
            $table->foreignId('vps_server_id')->nullable()
                  ->constrained('vps_servers')->nullOnDelete();

            $table->string('from_status')->nullable();
            $table->string('to_status');
            $table->string('reason')->nullable();          // "watchdog_restart", "login_failed", ...
            $table->decimal('cpu_pct', 5, 2)->nullable();
            $table->unsignedInteger('ram_mb')->nullable();

            $table->timestamp('created_at')->useCurrent();

            $table->index(['trading_account_id', 'created_at']);
            $table->index(['vps_server_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('terminal_status_logs');
    }
};
