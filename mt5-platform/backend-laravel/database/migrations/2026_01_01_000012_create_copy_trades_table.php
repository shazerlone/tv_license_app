<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Links a master position (ticket) to the slave position it produced.
     * This is what makes closes correct: when master ticket X closes, we find
     * the row and close exactly slave_ticket — even when two master symbols
     * map to the same slave symbol. Also enforces "copy each master trade once".
     */
    public function up(): void
    {
        Schema::create('copy_trades', function (Blueprint $table) {
            $table->id();
            $table->foreignId('copier_slave_id')->constrained('copier_slaves')->cascadeOnDelete();

            $table->unsignedBigInteger('master_ticket');
            $table->unsignedBigInteger('slave_ticket')->nullable();
            $table->string('master_symbol');
            $table->string('slave_symbol');
            $table->enum('side', ['buy', 'sell']);
            $table->decimal('master_volume', 10, 3);
            $table->decimal('slave_volume', 10, 3)->nullable();

            $table->enum('status', ['pending', 'open', 'closed', 'error'])->default('pending');
            $table->text('error')->nullable();
            $table->timestamp('opened_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();

            // One master ticket copies once per slave (dedup / idempotency).
            $table->unique(['copier_slave_id', 'master_ticket']);
            $table->index(['status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('copy_trades');
    }
};
