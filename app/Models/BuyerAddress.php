<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BuyerAddress extends Model
{
    protected $fillable = [
        'user_id', 'label', 'recipient_name', 'phone',
        'province', 'municipality', 'barangay', 'street', 'house_no',
        'postal_code', 'landmark', 'is_default',
    ];

    protected $casts = ['is_default' => 'boolean'];

    public function user() { return $this->belongsTo(User::class); }

    /** "123 Rizal Ave, Brgy. 67, Quezon City, Metro Manila, 1100" */
    public function getFullAddressAttribute(): string
    {
        $street = trim(($this->house_no ? $this->house_no . ' ' : '') . $this->street);
        return collect([$street, 'Brgy. ' . $this->barangay, $this->municipality, $this->province, $this->postal_code])
            ->filter()->join(', ');
    }

    /** Frozen copy stored on orders so later edits don't rewrite history. */
    public function snapshot(): array
    {
        return [
            'label'          => $this->label,
            'recipient_name' => $this->recipient_name,
            'phone'          => $this->phone,
            'full_address'   => $this->full_address,
            'landmark'       => $this->landmark,
            'province'       => $this->province,
            'municipality'   => $this->municipality,
            'barangay'       => $this->barangay,
        ];
    }
}
