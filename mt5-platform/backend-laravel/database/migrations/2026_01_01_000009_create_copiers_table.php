<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** A copier group = one MASTER account fanning out to many slaves. */
    public function up(): void
    {
        Schema::create('copiers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('master_account_id')
                  ->constrained('trading_accounts')->cascadeOnDelete();
            $table->string('name')->nullable();
            $table->boolean('enabled')->default(true);
            // Per your choice: only copy trades opened AFTER the link goes live.
            $table->boolean('copy_new_only')->default(true);
            $table->timestamps();

            $table->unique('master_account_id');   // one copier config per master
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('copiers');
    }
};
