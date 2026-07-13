<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trading_accounts', function (Blueprint $table) {
            $table->id();

            // The "meta details" the operator enters in the UI.
            $table->string('login');                          // MT5 account number
            $table->string('broker_server');                  // e.g. "ICMarketsSC-Demo"
            $table->text('password_encrypted');               // Laravel 'encrypted' cast (AES-256-GCM)
            $table->enum('password_type', ['investor', 'master'])->default('master');

            $table->string('label')->nullable();              // operator-friendly name
            $table->string('owner')->nullable();              // who this account belongs to
            $table->unsignedBigInteger('license_id')->nullable(); // ties into existing licenses.json/signal flow

            // Desired vs observed. desired_state = what we WANT to happen.
            $table->enum('desired_state', ['running', 'stopped'])->default('running');

            // Placement: which VPS this account is currently assigned to (nullable = unassigned).
            $table->foreignId('vps_server_id')->nullable()
                  ->constrained('vps_servers')->nullOnDelete();

            $table->enum('status', [
                'unassigned', 'assigned', 'connecting', 'connected',
                'disconnected', 'errored', 'stopped',
            ])->default('unassigned');

            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('last_connected_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            // A given MT5 login is unique per broker server.
            $table->unique(['login', 'broker_server']);
            $table->index(['vps_server_id', 'status']);
            $table->index(['desired_state', 'vps_server_id']);   // scheduler: find running+unassigned
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trading_accounts');
    }
};
