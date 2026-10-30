<?php

namespace App\Models\Pickrush;

use App\Models\Order;
use Illuminate\Database\Eloquent\Model;

/** Read-only view of a Pickrush parcel booked for a marketplace order (see the website's PicksellBridge). */
class Parcel extends Model
{
    public const SOURCE = 'picksell';

    protected $table = 'pr_parcels';

    public function events()
    {
        return $this->hasMany(ParcelEvent::class)->orderBy('occurred_at')->orderBy('id');
    }

    public static function forOrder(Order $order): ?self
    {
        return self::where('source', self::SOURCE)->where('external_ref', (string) $order->id)->first();
    }
}
