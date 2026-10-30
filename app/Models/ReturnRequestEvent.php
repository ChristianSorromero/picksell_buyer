<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ReturnRequestEvent extends Model
{
    protected $fillable = [
        'return_request_id', 'actor_user_id', 'event_type', 'from_status',
        'to_status', 'notes', 'metadata',
    ];

    protected $casts = ['metadata' => 'array'];

    public function returnRequest() { return $this->belongsTo(ReturnRequest::class); }
}
