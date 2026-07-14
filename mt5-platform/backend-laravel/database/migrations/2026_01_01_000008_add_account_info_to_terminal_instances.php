<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Real account data pulled from MT5 (balance/equity/open trades). These make
     * "connected" trustworthy: they only populate when the terminal actually
     * logged in and returned account_info().
     */
    public function up(): void
    {
        Schema::table('terminal_instances', function (Blueprint $table) {
            $table->boolean('login_verified')->default(false)->after('mt5_connected');
            $table->decimal('balance', 18, 2)->nullable()->after('login_verified');
            $table->decimal('equity', 18, 2)->nullable()->after('balance');
            $table->decimal('profit', 18, 2)->nullable()->after('equity');
            $table->unsignedInteger('open_trades')->nullable()->after('profit');
            $table->string('account_currency', 8)->nullable()->after('open_trades');
            $table->unsignedInteger('leverage')->nullable()->after('account_currency');
        });
    }

    public function down(): void
    {
        Schema::table('terminal_instances', function (Blueprint $table) {
            $table->dropColumn([
                'login_verified', 'balance', 'equity', 'profit',
                'open_trades', 'account_currency', 'leverage',
            ]);
        });
    }
};
