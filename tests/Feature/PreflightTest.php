<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PreflightTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_blocks_a_non_production_configuration(): void
    {
        config(['app.env' => 'testing', 'app.debug' => true, 'mail.default' => 'array']);

        $this->artisan('picksell:preflight')
            ->expectsOutputToContain('APP_DEBUG is on')
            ->expectsOutputToContain('Cash on Delivery is the only payment method')
            ->assertExitCode(1);
    }

    public function test_it_passes_a_production_ready_configuration(): void
    {
        config([
            'app.env' => 'production', 'app.debug' => false, 'app.url' => 'https://pick-sell.shop',
            'logging.channels.single.level' => 'warning', 'session.secure' => true,
            'mail.default' => 'smtp', 'database.connections.sqlite.username' => 'picksell_app',
        ]);

        $this->artisan('picksell:preflight')
            ->expectsOutputToContain('No pending migrations')
            ->expectsOutputToContain('Ledger balances')
            ->assertExitCode(0);
    }

    public function test_it_flags_cashless_payment_methods(): void
    {
        config(['picksell.payment_methods' => [
            ['code' => 'cod', 'name' => 'COD', 'available' => true],
            ['code' => 'gcash', 'name' => 'GCash', 'available' => true],
        ]]);

        $this->artisan('picksell:preflight')->expectsOutputToContain('Payment methods other than COD are enabled: cod, gcash')->assertExitCode(1);
    }
}
