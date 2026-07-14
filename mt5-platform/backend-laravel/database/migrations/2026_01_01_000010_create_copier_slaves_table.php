<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** A slave under a master, with its lot-sizing + risk rules. */
    public function up(): void
    {
        Schema::create('copier_slaves', function (Blueprint $table) {
            $table->id();
            $table->foreignId('copier_id')->constrained('copiers')->cascadeOnDelete();
            $table->foreignId('slave_account_id')
                  ->constrained('trading_accounts')->cascadeOnDelete();
            $table->boolean('enabled')->default(true);

            // Lot sizing.
            $table->enum('lot_mode', ['multiplier', 'fixed', 'balance'])->default('multiplier');
            $table->decimal('lot_multiplier', 8, 3)->default(1.0);     // slave = master * x
            $table->decimal('fixed_lots', 8, 3)->nullable();           // lot_mode=fixed
            $table->decimal('balance_multiplier', 8, 3)->default(1.0); // scales the balance ratio

            // Risk calculator (optional): size lot to risk this % of slave balance per trade.
            $table->decimal('risk_percent', 6, 3)->nullable();

            // Safety + behaviour.
            $table->decimal('min_lot', 8, 3)->nullable();
            $table->decimal('max_lot', 8, 3)->nullable();
            $table->boolean('reverse')->default(false);        // copy buy<->sell inverted
            $table->boolean('copy_sl_tp')->default(true);
            $table->unsignedSmallInteger('max_slippage_points')->default(20);

            $table->timestamps();

            $table->unique(['copier_id', 'slave_account_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('copier_slaves');
    }
};
