<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Admin
        User::create([
            'role'           => 'admin',
            'status'         => 'approved',
            'last_name'      => 'Admin',
            'first_name'     => 'PickSell',
            'middle_initial' => null,
            'sex'            => 'Male',
            'email'          => 'admin@picksell.ph',
            'password'       => Hash::make('Admin@1234'),
            'contact_no'     => '09000000000',
            'birthday'       => '1990-01-01',
            'age'            => 35,
            'province'       => 'Metro Manila',
            'municipality'   => 'Makati',
            'barangay'       => 'Poblacion',
        ]);

        // Seller
        User::create([
            'role'             => 'seller',
            'status'           => 'approved',
            'last_name'        => 'Dela Cruz',
            'first_name'       => 'Juan',
            'middle_initial'   => 'S',
            'sex'              => 'Male',
            'email'            => 'seller@picksell.ph',
            'password'         => Hash::make('Seller@1234'),
            'contact_no'       => '09111111111',
            'birthday'         => '1995-06-15',
            'age'              => 29,
            'province'         => 'Cebu',
            'municipality'     => 'Cebu City',
            'barangay'         => 'Lahug',
            'street'           => 'Gorordo Ave',
            'house_no'         => '12B',
            'business_name'    => "Juan's Store",
            'line_of_business' => 'Electronics',
            'id_upload'        => null,
            'business_permit'  => null,
        ]);

        // Buyer
        User::create([
            'role'           => 'buyer',
            'status'         => 'approved',
            'last_name'      => 'Reyes',
            'first_name'     => 'Maria',
            'middle_initial' => 'L',
            'sex'            => 'Female',
            'email'          => 'buyer@picksell.ph',
            'password'       => Hash::make('Buyer@1234'),
            'contact_no'     => '09222222222',
            'birthday'       => '2000-03-20',
            'age'            => 25,
            'province'       => 'Metro Manila',
            'municipality'   => 'Quezon City',
            'barangay'       => 'Diliman',
            'street'         => 'Katipunan Ave',
            'house_no'       => '45A',
            'id_upload'      => null,
        ]);

        $this->call([
            ProductSeeder::class,
            CourierSeeder::class,
            BuyerDemoSeeder::class,
        ]);
    }
}
