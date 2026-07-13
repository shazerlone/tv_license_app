<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * `is_managed` distinguishes accounts the platform launches & controls
     * (true) from terminals merely DISCOVERED already running on a VPS (false).
     * Discovered ones are monitor-only: shown with live stats but never
     * assigned, started, stopped, or restarted by the agent.
     */
    public function up(): void
    {
        Schema::table('trading_accounts', function (Blueprint $table) {
            $table->boolean('is_managed')->default(true)->after('desired_state');
        });
    }

    public function down(): void
    {
        Schema::table('trading_accounts', function (Blueprint $table) {
            $table->dropColumn('is_managed');
        });
    }
};
