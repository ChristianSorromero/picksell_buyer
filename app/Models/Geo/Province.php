<?php

namespace App\Models\Geo;

/** A province, or one of Metro Manila's four districts (kind = district). */
class Province extends GeoModel
{
    protected $table = 'geo_provinces';

    public function region()
    {
        return $this->belongsTo(Region::class, 'region_code');
    }

    public function municipalities()
    {
        return $this->hasMany(Municipality::class, 'province_code');
    }

    public function isDistrict(): bool
    {
        return $this->kind === 'district';
    }
}
