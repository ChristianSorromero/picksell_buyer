<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Announcement extends Model
{
    protected $fillable = ['title', 'message', 'audience', 'active'];

    protected $casts = ['active' => 'boolean'];
}
