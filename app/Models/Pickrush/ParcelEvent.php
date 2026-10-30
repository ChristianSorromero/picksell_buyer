<?php

namespace App\Models\Pickrush;

use Illuminate\Database\Eloquent\Model;

/** Read-only Pickrush scan. Headlines match the website's buyer tracking page. */
class ParcelEvent extends Model
{
    protected $table = 'pr_parcel_events';

    protected $casts = ['occurred_at' => 'datetime'];

    public function hub()   { return $this->belongsTo(Hub::class, 'hub_id'); }
    public function toHub() { return $this->belongsTo(Hub::class, 'to_hub_id'); }

    public function headline(): string
    {
        $hub = $this->hub?->name;
        $to = $this->toHub?->name;

        return match ($this->status) {
            'waiting_pickup' => 'Shipment created, waiting for pickup',
            'picked_up' => 'Picked up from the seller',
            'at_origin_hub', 'at_province_hub', 'arrived_at_station' => 'Arrived at '.($hub ?? 'hub'),
            'in_transit_to_province', 'in_transit_to_station' => 'Departed '.($hub ?? 'hub').($to ? ' → '.$to : ''),
            'assigned_to_rider' => 'Rider assigned for delivery',
            'out_for_delivery' => 'Out for delivery',
            'delivered' => 'Delivered',
            'delivery_failed' => 'Delivery attempt unsuccessful',
            'on_hold' => 'On hold at '.($hub ?? 'hub'),
            'returning_to_sender' => 'Returning to the seller',
            'returned_to_sender' => 'Returned to the seller',
            'cancelled' => 'Shipment cancelled',
            'lost' => 'Reported lost; our team is investigating',
            default => ucfirst(str_replace('_', ' ', (string) $this->status)),
        };
    }
}
