<?php

namespace App\Models\Geo;

use Illuminate\Database\Eloquent\Model;

/** PSGC reference rows: keyed by the 9-digit PSA code, read-only after import. */
abstract class GeoModel extends Model
{
    protected $primaryKey = 'code';

    protected $keyType = 'string';

    public $incrementing = false;

    public $timestamps = false;

    protected $guarded = [];
}
