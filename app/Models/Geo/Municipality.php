<?php

namespace App\Models\Geo;

/** A city or municipality. */
class Municipality extends GeoModel
{
    protected $table = 'geo_municipalities';

    protected $casts = ['is_city' => 'boolean', 'is_capital' => 'boolean'];

    public function province()
    {
        return $this->belongsTo(Province::class, 'province_code');
    }

    public function barangays()
    {
        return $this->hasMany(Barangay::class, 'municipality_code');
    }
}
