<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Remove expired / long-unused API tokens (see config/sanctum.php expiration).
\Illuminate\Support\Facades\Schedule::command('sanctum:prune-expired --hours=24')->daily();

// Settle orders whose cash is handed in and whose return window has passed.
// Idempotent: each order can only be settled once.
Artisan::command('picksell:settle-orders', function (\App\Services\Settlements $settlements) {
    $this->info($settlements->settleEligible() . ' order(s) settled.');
})->purpose('Settle eligible COD orders into seller and rider payables');
\Illuminate\Support\Facades\Schedule::command('picksell:settle-orders')->dailyAt('02:00');
