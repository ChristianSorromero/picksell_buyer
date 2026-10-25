<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * What a seller has given Picksell for RR 16-2023 purposes. Recorded and
 * verified by an admin; withholding itself stays off until reviewed.
 */
class SellerTaxProfile extends Model
{
    protected $fillable = [
        'seller_id', 'tin', 'bir_cor_number', 'sworn_declaration_year', 'sworn_declaration_received_on',
        'exemption_type', 'exemption_reference', 'verified_by', 'verified_at', 'notes',
    ];

    protected $casts = ['sworn_declaration_received_on' => 'date', 'verified_at' => 'datetime'];

    public function seller()     { return $this->belongsTo(User::class, 'seller_id'); }
    public function verifiedBy() { return $this->belongsTo(User::class, 'verified_by'); }

    /** A verified sworn declaration for [$year] (under the ₱500,000 threshold). */
    public function hasDeclarationFor(int $year): bool
    {
        return $this->verified_at !== null && $this->sworn_declaration_year === $year;
    }
}
