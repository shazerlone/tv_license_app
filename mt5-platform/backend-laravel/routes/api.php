<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\Agent\AssignmentController;
use App\Http\Controllers\Api\Agent\EventController;
use App\Http\Controllers\Api\Agent\HeartbeatController;
use App\Http\Controllers\Api\ServerController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Operator API  (auth: sanctum — the dashboard / Flutter app)
|--------------------------------------------------------------------------
*/
Route::middleware(['auth:sanctum', 'throttle:120,1'])->group(function () {

    // Trading accounts (the operator's "meta details")
    Route::get   ('accounts',                 [AccountController::class, 'index']);
    Route::post  ('accounts',                 [AccountController::class, 'store']);
    Route::get   ('accounts/{account}',       [AccountController::class, 'show']);
    Route::post  ('accounts/{account}/restart',[AccountController::class, 'restart']);
    Route::post  ('accounts/{account}/stop',  [AccountController::class, 'stop']);
    Route::post  ('accounts/{account}/start', [AccountController::class, 'start']);
    Route::delete('accounts/{account}',       [AccountController::class, 'destroy']);

    // VPS fleet
    Route::get   ('servers',                  [ServerController::class, 'index']);
    Route::post  ('servers',                  [ServerController::class, 'store']);
    Route::get   ('servers/{server}',         [ServerController::class, 'show']);
    Route::get   ('servers/{server}/health',  [ServerController::class, 'health']);
    Route::post  ('servers/{server}/status',  [ServerController::class, 'setStatus']);
    Route::post  ('servers/{server}/rotate-token', [ServerController::class, 'rotateToken']);
});

/*
|--------------------------------------------------------------------------
| Agent API  (auth: per-VPS bearer token via AuthenticateAgent middleware)
|   Prefix: /api/agent  •  every route is scoped to the calling VPS.
|--------------------------------------------------------------------------
*/
Route::prefix('agent')
    ->middleware(['agent.auth', 'throttle:600,1'])   // ~10 req/s/VPS headroom
    ->group(function () {
        Route::get ('assignments', [AssignmentController::class, 'index']);
        Route::post('heartbeat',   [HeartbeatController::class, 'store']);
        Route::post('events',      [EventController::class, 'store']);
    });
