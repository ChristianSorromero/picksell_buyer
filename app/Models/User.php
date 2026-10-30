<?php

namespace App\Models;

use App\Services\Geo\AddressResolver;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * A row of the shared Picksell `users` table. Buyers created from the app follow the website's
 * rules: pending until an admin approves them, address codes kept in step with the names.
 */
class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'role', 'status',
        'last_name', 'first_name', 'middle_initial', 'sex',
        'email', 'password', 'contact_no', 'birthday', 'age',
        'province', 'municipality', 'barangay', 'street', 'house_no',
        'id_upload',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = ['birthday' => 'date', 'email_verified_at' => 'datetime'];

    protected static function booted(): void
    {
        // Same as the website: keep the PSGC codes in step with the address names. Pickrush
        // routes deliveries by these codes.
        static::saving(function (User $user): void {
            if ($user->isDirty(['province', 'municipality', 'barangay'])) {
                $user->forceFill(app(AddressResolver::class)->resolve($user->province, $user->municipality, $user->barangay));
            }
        });
    }

    public function getFullNameAttribute(): string
    {
        $mi = $this->middle_initial ? " {$this->middle_initial}." : '';

        return "{$this->first_name}{$mi} {$this->last_name}";
    }

    public function isApproved(): bool
    {
        return $this->status === 'approved';
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function cart()
    {
        return $this->hasOne(Cart::class, 'buyer_id');
    }

    public function buyerOrders()
    {
        return $this->hasMany(Order::class, 'buyer_id');
    }

    public function products()
    {
        return $this->hasMany(Product::class, 'seller_id');
    }

    public function wishlistItems()
    {
        return $this->hasMany(WishlistItem::class);
    }

    public function recentlyViewedProducts()
    {
        return $this->hasMany(RecentlyViewedProduct::class);
    }
}
