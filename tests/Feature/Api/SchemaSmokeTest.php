<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class SchemaSmokeTest extends TestCase
{
    use RefreshDatabase;

    public function test_tests_run_on_the_website_schema(): void
    {
        foreach (['orders', 'wishlist_items', 'recently_viewed_products', 'personal_access_tokens', 'pr_parcels', 'geo_barangays'] as $table) {
            $this->assertTrue(Schema::hasTable($table), "missing {$table}");
        }
        $this->assertTrue(Schema::hasColumn('orders', 'commission_rate'));
        $this->getJson('/api/ping')->assertOk();
    }
}
