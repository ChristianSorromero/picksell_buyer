<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
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

    protected $hidden = ['password', 'remember_token'];

    protected $casts = ['birthday' => 'date', 'email_verified_at' => 'datetime'];

    public function getFullNameAttribute(): string
    {
        $mi = $this->middle_initial ? " {$this->middle_initial}." : '';
        return "{$this->first_name}{$mi} {$this->last_name}";
    }

    public function getAgeAttribute(): ?int
    {
        return $this->birthday ? $this->birthday->age : null;
    }

    public function isApproved(): bool { return $this->status === 'approved'; }
    public function isPending(): bool  { return $this->status === 'pending'; }

    public function sentMessages()     { return $this->hasMany(Message::class, 'sender_id'); }
    public function receivedMessages() { return $this->hasMany(Message::class, 'receiver_id'); }
    public function complaints()       { return $this->hasMany(Complaint::class, 'filed_by'); }
    public function ordersAsBuyer()    { return $this->hasMany(Order::class, 'buyer_id'); }
    public function ordersAsSeller()   { return $this->hasMany(Order::class, 'seller_id'); }
    public function ordersAsCourier()  { return $this->hasMany(Order::class, 'courier_id'); }
    public function products()         { return $this->hasMany(\App\Models\Product::class, 'seller_id'); }
}
