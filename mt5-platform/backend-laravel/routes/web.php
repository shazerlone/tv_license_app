<?php

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
});
