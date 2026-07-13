<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('terminal_instances', function (Blueprint $table) {
            $table->id();

            $table->foreignId('trading_account_id')
                  ->constrained('trading_accounts')->cascadeOnDelete();
            $table->foreignId('vps_server_id')
                  ->constrained('vps_servers')->cascadeOnDelete();

            // Local identity on the VPS.
            $table->unsignedInteger('os_pid')->nullable();       // terminal64.exe PID
            $table->string('data_dir')->nullable();              // per-account portable dir
            $table->string('instance_key')->nullable();          // stable id agent uses (e.g. acct login)

            $table->enum('status', [
                'starting', 'running', 'connected',
                'crashed', 'restarting', 'stopped', 'errored',
            ])->default('starting');

            // Last observed per-terminal resource usage (denormalised for dashboard).
            $table->decimal('cpu_pct', 5, 2)->nullable();
            $table->unsignedInteger('ram_mb')->nullable();
            $table->boolean('mt5_connected')->default(false);    // reported terminal→broker link

            // Watchdog bookkeeping.
            $table->unsignedInteger('restart_count')->default(0);
            $table->timestamp('last_restart_at')->nullable();
            $table->text('last_error')->nullable();

            $table->timestamp('started_at')->nullable();
            $table->timestamp('last_heartbeat_at')->nullable();
            $table->timestamps();

            // One live instance per account.
            $table->unique('trading_account_id');
            $table->index(['vps_server_id', 'status']);
            $table->index('last_heartbeat_at');                  // stale sweep
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('terminal_instances');
    }
};
