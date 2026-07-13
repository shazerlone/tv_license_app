<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Discrete, at-least-once events pushed by the agent (crash, restart,
     * login_failed, resource_limit, etc.). The agent generates a client-side
     * `event_uid` so re-sends are deduped here (idempotent ingest).
     */
    public function up(): void
    {
        Schema::create('terminal_events', function (Blueprint $table) {
            $table->id();

            $table->uuid('event_uid')->unique();               // idempotency key from agent
            $table->foreignId('vps_server_id')
                  ->constrained('vps_servers')->cascadeOnDelete();
            $table->foreignId('trading_account_id')->nullable()
                  ->constrained('trading_accounts')->nullOnDelete();
            $table->foreignId('terminal_instance_id')->nullable()
                  ->constrained('terminal_instances')->nullOnDelete();

            $table->enum('type', [
                'crashed', 'restarted', 'login_failed', 'disconnected',
                'resource_limit', 'started', 'stopped', 'agent_started', 'agent_error',
            ]);
            $table->enum('severity', ['info', 'warning', 'error', 'critical'])->default('info');
            $table->text('message')->nullable();
            $table->json('context')->nullable();               // free-form details
            $table->timestamp('occurred_at');                  // when it happened on the VPS

            $table->timestamps();

            $table->index(['vps_server_id', 'occurred_at']);
            $table->index(['type', 'severity']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('terminal_events');
    }
};
