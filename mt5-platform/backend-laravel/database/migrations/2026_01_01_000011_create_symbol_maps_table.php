<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * master_symbol -> slave_symbol, per slave. Many-to-one is supported:
     * e.g. both GOLD_Cash -> xauusdc and XAU.CASH -> xauusdc for one slave.
     * If a master symbol has no row here, the copier can pass it through
     * unchanged (configurable on the slave).
     */
    public function up(): void
    {
        Schema::create('symbol_maps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('copier_slave_id')->constrained('copier_slaves')->cascadeOnDelete();
            $table->string('master_symbol');
            $table->string('slave_symbol');
            $table->timestamps();

            // A master symbol maps once per slave (but many masters symbols may
            // point at the same slave symbol — that's the many-to-one case).
            $table->unique(['copier_slave_id', 'master_symbol']);
            $table->index(['copier_slave_id', 'slave_symbol']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('symbol_maps');
    }
};
