<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'role', 'status', 'provider_type',
        'last_name', 'first_name', 'middle_initial', 'sex',
        'email', 'password', 'contact_no', 'birthday', 'age',
        'province', 'municipality', 'barangay', 'street', 'house_no',
        'id_upload',
        // Seller
        'business_name', 'line_of_business', 'business_permit',
        // Courier
        'vehicle_type', 'plate_number', 'or_cr_upload', 'delivery_area',
    ];

    protected $hidden = ['password', 'remember_token', 'email_verification_code'];

    protected $casts = [
        'birthday'                      => 'date',
        'email_verified_at'             => 'datetime',
        'email_verification_expires_at' => 'datetime',
        'email_verification_sent_at'    => 'datetime',
        'terms_accepted_at'             => 'datetime',
        'notifications_seen_at'         => 'datetime',
        'anonymized_at'                 => 'datetime',
    ];

    public function getFullNameAttribute(): string
    {
        $mi = $this->middle_initial ? " {$this->middle_initial}." : '';
        return "{$this->first_name}{$mi} {$this->last_name}";
    }

    public function getAgeAttribute(): ?int
    {
        return $this->birthday ? $this->birthday->age : null;
    }

    public function isApproved(): bool   { return $this->status === 'approved'; }
    public function isPending(): bool    { return $this->status === 'pending'; }
    public function isAnonymized(): bool { return $this->anonymized_at !== null; }

    /** Orders or returns this account is still part of, as any role. */
    public function hasOpenOrders(): bool
    {
        $orders = Order::where(fn ($q) => $q->where('buyer_id', $this->id)->orWhere('seller_id', $this->id)
            ->orWhere('courier_id', $this->id)->orWhere('logistics_id', $this->id));

        return (clone $orders)->whereNotIn('status', ['completed', 'cancelled'])->exists()
            || ReturnRequest::whereIn('status', ['requested', 'under_review', 'processing'])
                ->whereIn('order_id', (clone $orders)->select('id'))->exists();
    }

    /**
     * Closes the account: personal data and uploaded documents are erased
     * and the person can no longer sign in, but the row stays so other
     * people's orders, returns and chats keep their history.
     */
    public function anonymize(): void
    {
        DB::transaction(function () {
            foreach (['id_upload', 'business_permit', 'or_cr_upload'] as $document) {
                if ($this->{$document}) Storage::disk('local')->delete($this->{$document});
            }

            $this->tokens()->delete();
            $this->addresses()->delete();
            $this->wishlist()->delete();
            Cart::where('buyer_id', $this->id)->delete();
            $this->products()->update(['status' => 'archived']);
            Voucher::where('seller_id', $this->id)->update(['active' => false]);

            // business_name stays so past orders still show which store sold them.
            $this->forceFill([
                'status'         => 'deactivated',
                'anonymized_at'  => now(),
                'first_name'     => 'Deleted',
                'last_name'      => 'User',
                'middle_initial' => null,
                'sex'            => null,
                'email'          => "deleted-{$this->id}@deleted.invalid",
                'password'       => Hash::make(Str::random(64)),
                'remember_token' => null,
                'contact_no'     => '',
                'birthday'       => '1900-01-01', // required column; real date erased
                'age'            => 0,
                'province'       => null,
                'municipality'   => null,
                'barangay'       => null,
                'street'         => null,
                'house_no'       => null,
                'id_upload'      => null,
                'business_permit' => null,
                'plate_number'   => null,
                'or_cr_upload'   => null,
                'email_verification_code' => null,
            ])->save();
        });
    }

    public function sentMessages()     { return $this->hasMany(Message::class, 'sender_id'); }
    public function receivedMessages() { return $this->hasMany(Message::class, 'receiver_id'); }
    public function complaints()       { return $this->hasMany(Complaint::class, 'filed_by'); }
    public function ordersAsBuyer()    { return $this->hasMany(Order::class, 'buyer_id'); }
    public function ordersAsSeller()   { return $this->hasMany(Order::class, 'seller_id'); }
    public function ordersAsCourier()  { return $this->hasMany(Order::class, 'courier_id'); }
    public function products()         { return $this->hasMany(\App\Models\Product::class, 'seller_id'); }
    public function addresses()        { return $this->hasMany(BuyerAddress::class); }
    public function wishlist()         { return $this->hasMany(WishlistItem::class); }
}
