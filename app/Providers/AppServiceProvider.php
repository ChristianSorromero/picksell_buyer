<?php

namespace App\Providers;

use App\Support\LocalTime;
use Carbon\CarbonImmutable;
use Illuminate\Support\Carbon;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Views: $order->created_at->forDisplay()->format(...) shows Philippine time.
        $forDisplay = function () {
            return LocalTime::of($this);
        };
        Carbon::macro('forDisplay', $forDisplay);
        CarbonImmutable::macro('forDisplay', $forDisplay);
    }
}
