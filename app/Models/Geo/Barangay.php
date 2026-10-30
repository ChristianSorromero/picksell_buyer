<?php

namespace App\Models\Geo;

class Barangay extends GeoModel
{
    protected $table = 'geo_barangays';

    public function municipality()
    {
        return $this->belongsTo(Municipality::class, 'municipality_code');
    }
}
