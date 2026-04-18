<?php

declare(strict_types=1);

use App\Http\Controllers\Settings\ProfileController;
use App\Http\Controllers\Settings\SecurityController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth'])->prefix('settings')->group(function () {
    Route::redirect('/', '/settings/profile');

    Route::get('profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('profile', [ProfileController::class, 'update'])->name('profile.update');

    Route::middleware(['verified'])->group(function () {
        Route::delete('profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

        Route::get('security', [SecurityController::class, 'edit'])->name('security.edit');

        Route::put('password', [SecurityController::class, 'update'])
            ->middleware('throttle:6,1')
            ->name('user-password.update');

        Route::inertia('appearance', 'settings/appearance')->name('appearance.edit');
    });
});
