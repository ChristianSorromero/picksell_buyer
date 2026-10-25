<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Complaint extends Model
{
    protected $fillable = [
        'filed_by', 'against_user_id', 'order_id', 'category', 'subject', 'details',
        'evidence_path', 'evidence_paths', 'status', 'admin_notes',
    ];

    protected $casts = [
        'evidence_paths' => 'array',
    ];

    public function filer()   { return $this->belongsTo(User::class, 'filed_by'); }
    public function against() { return $this->belongsTo(User::class, 'against_user_id'); }
    public function order()   { return $this->belongsTo(Order::class); }
}
