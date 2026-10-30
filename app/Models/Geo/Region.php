<?php

namespace App\Models\Geo;

class Region extends GeoModel
{
    protected $table = 'geo_regions';

    public function provinces()
    {
        return $this->hasMany(Province::class, 'region_code');
    }
}
