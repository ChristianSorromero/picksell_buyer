<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

/**
 * Intentionally empty. This app shares the live Picksell website database, so it must never
 * insert demo data. Seed development data from the Picksell website project instead.
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->command?->warn('Nothing to seed: this app uses the Picksell website database.');
    }
}
