<?php

namespace App\Models;

use App\Services\AdminNotificationService;
use Illuminate\Database\Eloquent\Model;

/** Buyer reports ("Report a problem"); admins handle them on the website's Complaints page. */
class Complaint extends Model
{
    protected $fillable = [
        'filed_by', 'against_user_id', 'subject', 'details',
        'evidence_path', 'order_id', 'status', 'admin_notes',
    ];

    protected $casts = ['resolved_at' => 'datetime'];

    public function filer()   { return $this->belongsTo(User::class, 'filed_by'); }
    public function against() { return $this->belongsTo(User::class, 'against_user_id'); }
    public function order()   { return $this->belongsTo(Order::class); }

    protected static function booted(): void
    {
        // Same alert the website raises for a new complaint.
        static::created(function (Complaint $complaint): void {
            app(AdminNotificationService::class)->notifyAdmins(
                'complaint.opened',
                'Complaint opened',
                "A complaint was filed: {$complaint->subject}.",
                "/admin/complaints/{$complaint->id}",
            );
        });
    }
}
