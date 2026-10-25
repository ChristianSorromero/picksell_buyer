<?php

namespace Database\Seeders;

use App\Models\BuyerAddress;
use App\Models\Product;
use App\Models\ProductVariation;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

/**
 * DEV ONLY — makes the mobile buyer journey testable end to end:
 * product photos, variations, vouchers, a logistics partner and a
 * verified buyer with a default address. Safe to run repeatedly.
 *
 *   php artisan db:seed --class=BuyerDemoSeeder
 */
class BuyerDemoSeeder extends Seeder
{
    /** Keyword in product name/category → demo photo. */
    private const PHOTOS = [
        'headphone' => 'headphones.jpg', 'speaker' => 'headphones.jpg',
        'watch' => 'watch.jpg',
        'laptop' => 'laptop.jpg', 'mouse' => 'laptop.jpg', 'workstation' => 'laptop.jpg', 'hub' => 'laptop.jpg',
        'bag' => 'bag.jpg', 'tote' => 'bag.jpg', 'backpack' => 'bag.jpg', 'duffel' => 'bag.jpg',
        'sneaker' => 'shoes.jpg', 'shoe' => 'shoes.jpg',
        'shirt' => 'clothes.jpg', 'cap' => 'clothes.jpg', 'fashion' => 'clothes.jpg',
        'serum' => 'perfume.jpg', 'fragrance' => 'perfume.jpg', 'lotion' => 'perfume.jpg', 'facial' => 'perfume.jpg', 'beauty' => 'perfume.jpg', 'brush' => 'perfume.jpg',
        'coffee' => 'food.jpg', 'blender' => 'food.jpg', 'mug' => 'food.jpg', 'bottle' => 'food.jpg',
        'lamp' => 'decor.jpg', 'basket' => 'decor.jpg', 'home' => 'decor.jpg',
    ];

    public function run(): void
    {
        // Creates accounts with published passwords; never in production.
        if (app()->isProduction()) {
            $this->command?->warn('BuyerDemoSeeder skipped: demo accounts are not created in production.');
            return;
        }

        $this->photos();
        $this->variations();
        $seller = User::where('email', 'seller@picksell.ph')->first();
        $this->vouchers($seller);
        $this->logistics();
        $this->buyer();
    }

    private function photos(): void
    {
        $source = database_path('seeders/demo-images');
        $disk = Storage::disk('public');

        Product::all()->each(function (Product $p) use ($source, $disk) {
            if ($p->image && $disk->exists($p->image)) return;

            $haystack = strtolower($p->name . ' ' . $p->category);
            $file = collect(self::PHOTOS)->first(fn ($f, $kw) => str_contains($haystack, $kw)) ?? 'decor.jpg';
            $path = $p->image ?: 'products/' . str($p->name)->slug() . '.jpg';

            $disk->put($path, File::get("{$source}/{$file}"));
            $p->update(['image' => $path]);
        });
    }

    private function variations(): void
    {
        $sets = [
            'Wireless Noise-Cancelling Headphones' => ['Color' => ['Midnight Black' => 10, 'Arctic White' => 8]],
            'Linen Blend Oversized Shirt'          => ['Color' => ['White' => 12, 'Sand' => 14], 'Size' => ['S' => 6, 'M' => 10, 'L' => 10]],
            'Everyday Training Sneakers'           => ['Size' => ['US 7' => 10, 'US 8' => 14, 'US 9' => 12, 'US 10' => 6]],
            'Smart Watch Series 5'                 => ['Color' => ['Graphite' => 12, 'Rose Gold' => 12], 'Strap' => ['Silicone' => 14, 'Leather' => 10]],
            'Stainless Steel Water Bottle'         => ['Size' => ['500ml' => 12, '750ml' => 13]],
        ];

        foreach ($sets as $name => $types) {
            $product = Product::where('name', $name)->first();
            if (!$product || $product->variations()->exists()) continue;
            foreach ($types as $type => $values) {
                foreach ($values as $value => $stock) {
                    ProductVariation::create(['product_id' => $product->id, 'type' => $type, 'value' => $value, 'stock' => $stock]);
                }
            }
        }
    }

    private function vouchers(?User $seller): void
    {
        $rows = [
            ['code' => 'WELCOME50', 'scope' => 'platform', 'type' => 'fixed', 'value' => 50, 'min_spend' => 500, 'is_limited' => true, 'usage_limit' => 500, 'expires_at' => now()->addMonths(2)],
            ['code' => 'SAVE100', 'scope' => 'platform', 'type' => 'fixed', 'value' => 100, 'min_spend' => 1500, 'expires_at' => now()->addMonth()],
        ];
        if ($seller) {
            $rows[] = ['code' => 'JUANS5', 'scope' => 'store', 'seller_id' => $seller->id, 'type' => 'percent', 'value' => 5, 'min_spend' => 0, 'max_discount' => 200, 'expires_at' => now()->addMonths(3)];
        }
        foreach ($rows as $row) {
            Voucher::updateOrCreate(['code' => $row['code']], $row + ['active' => true]);
        }
    }

    private function logistics(): void
    {
        User::firstOrCreate(['email' => 'logistics@picksell.test'], [
            'role' => 'logistics', 'status' => 'approved', 'provider_type' => 'courier_company',
            'first_name' => 'Picksell', 'last_name' => 'Logistics', 'business_name' => 'Picksell Express',
            'password' => Hash::make('Logistics@1234'), 'contact_no' => '09333333333',
            'birthday' => '1990-01-01', 'age' => 35,
            'province' => 'Metro Manila', 'municipality' => 'Pasig', 'barangay' => 'Kapitolyo',
            'delivery_area' => 'Metro Manila',
        ]);
    }

    private function buyer(): void
    {
        $buyer = User::firstOrCreate(['email' => 'buyer@picksell.ph'], [
            'role' => 'buyer', 'status' => 'approved', 'first_name' => 'Maria', 'last_name' => 'Reyes',
            'password' => Hash::make('Buyer@1234'), 'contact_no' => '09222222222',
            'birthday' => '2000-03-20', 'age' => 25,
        ]);
        $buyer->forceFill(['email_verified_at' => $buyer->email_verified_at ?? now()])->save();

        if (!$buyer->addresses()->exists()) {
            BuyerAddress::create([
                'user_id' => $buyer->id, 'label' => 'home', 'recipient_name' => 'Maria Reyes', 'phone' => '09222222222',
                'province' => 'Metro Manila', 'municipality' => 'Quezon City', 'barangay' => 'Diliman',
                'street' => 'Katipunan Ave', 'house_no' => '45A', 'postal_code' => '1101',
                'landmark' => 'Near UP Town Center', 'is_default' => true,
            ]);
        }

        $this->command?->info('Demo buyer: buyer@picksell.ph / Buyer@1234');
    }
}
