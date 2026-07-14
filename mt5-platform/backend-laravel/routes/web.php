<?php

use App\Http\Controllers\CopierController;
use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect('/dashboard'));

// Auth (session)
Route::get('/login',  [DashboardController::class, 'showLogin'])->name('login');
Route::post('/login', [DashboardController::class, 'login'])->middleware('throttle:10,1');
Route::post('/logout', [DashboardController::class, 'logout'])->name('logout');

// Operator dashboard — session-authenticated
Route::middleware('auth')->group(function () {
    Route::get('/dashboard',       [DashboardController::class, 'index'])->name('dashboard');
    Route::get('/dashboard/data',  [DashboardController::class, 'data']);

    Route::post('/dashboard/servers',  [DashboardController::class, 'storeServer']);
    Route::post('/dashboard/accounts', [DashboardController::class, 'storeAccount']);
    Route::post('/dashboard/accounts/{account}/restart', [DashboardController::class, 'restart']);
    Route::post('/dashboard/accounts/{account}/stop',    [DashboardController::class, 'stop']);
    Route::post('/dashboard/accounts/{account}/start',   [DashboardController::class, 'start']);
    Route::delete('/dashboard/accounts/{account}',       [DashboardController::class, 'destroy']);

    // Trade copier (tree UI)
    Route::get('/copier',                 [CopierController::class, 'index'])->name('copier');
    Route::get('/copier/data',            [CopierController::class, 'data']);
    Route::post('/copier',                [CopierController::class, 'store']);
    Route::post('/copier/{copier}/toggle',[CopierController::class, 'toggle']);
    Route::delete('/copier/{copier}',     [CopierController::class, 'destroy']);
    Route::post('/copier/{copier}/slaves',[CopierController::class, 'storeSlave']);
    Route::put('/copier/slaves/{slave}',  [CopierController::class, 'updateSlave']);
    Route::post('/copier/slaves/{slave}/toggle', [CopierController::class, 'toggleSlave']);
    Route::delete('/copier/slaves/{slave}',[CopierController::class, 'destroySlave']);
    Route::post('/copier/slaves/{slave}/maps', [CopierController::class, 'storeMap']);
    Route::delete('/copier/maps/{map}',   [CopierController::class, 'destroyMap']);
});
