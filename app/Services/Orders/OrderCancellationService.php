<?php

namespace App\Services\Orders;

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class OrderCancellationService
{
    private const CANCELLABLE_STATUSES = ['placed', 'confirmed', 'preparing'];

    public function cancel(Order $order, User $actor, string $role, ?string $reason = null): void
    {
        DB::transaction(function () use ($order, $actor, $role, $reason): void {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();
            $ownerColumn = $role === 'buyer' ? 'buyer_id' : 'seller_id';
            abort_unless($locked->{$ownerColumn} === $actor->id, 403);
            abort_unless(in_array($locked->status, self::CANCELLABLE_STATUSES, true), 409, 'This order can no longer be cancelled.');

            app(OrderLifecycleService::class)->transition(
                $locked,
                'cancelled',
                $actor->id,
                $role,
                $reason,
                ['tracking_status' => 'Order cancelled before pickup'],
            );
        });
    }
}
