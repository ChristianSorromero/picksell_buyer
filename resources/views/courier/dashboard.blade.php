@extends('courier.layout')
@section('title', 'Delivery Tasks')
@section('content')
@use('App\Support\Money')
@use('App\Support\OrderStatus')
<h1 style="margin:0 0 0.3rem;font-size:1.45rem;">Delivery Tasks</h1>
<p style="color:#888;margin:0 0 1.2rem;">Assigned area: <strong style="color:#2d2d2d;">{{ auth()->user()->delivery_area ?? 'Area not set' }}</strong></p>

<div class="stats">
    <div class="stat"><strong>{{ $stats['assigned'] }}</strong><span>Active Assignments</span></div>
    <div class="stat"><strong>{{ $stats['in_transit'] }}</strong><span>Out for Delivery</span></div>
    <div class="stat"><strong>{{ $stats['delivered'] }}</strong><span>Delivered</span></div>
    <div class="stat"><strong>{{ Money::format($stats['cash_on_hand']) }}</strong><span>Cash to Hand In</span></div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Rider Pay</span></div>
    <div style="padding:1rem;font-size:0.85rem;">
        @if($pay['status'] === 'unconfigured')
            <p style="margin:0;color:#b45309;"><strong>Not configured.</strong> Picksell has not set a rider pay rate yet, so no earnings are being recorded.</p>
        @elseif($pay['status'] === 'proposed')
            <p style="margin:0;color:#b45309;"><strong>Proposed, not active:</strong> {{ Money::format($pay['rates']['base_per_stop']) }} per stop, {{ Money::format($pay['rates']['additional_parcel']) }} per extra parcel at the same stop. Nothing is accrued until it is approved.</p>
        @else
            <p style="margin:0 0 0.4rem;">Active rate: {{ Money::format($pay['rates']['base_per_stop']) }} per stop, {{ Money::format($pay['rates']['additional_parcel']) }} per extra parcel at the same stop. Pay is recorded when the cash for a delivery is handed in.</p>
        @endif
        @if($pay['accrued'] > 0 || $pay['status'] === 'active')
            <p style="margin:0.4rem 0 0;">Earned: <strong>{{ Money::format($pay['accrued']) }}</strong> · Owed to you now: <strong>{{ Money::format($pay['owed']) }}</strong> · Paid out: {{ Money::format($pay['paid']) }}</p>
        @endif
    </div>
</div>

@if($pickups->isNotEmpty())
<div class="card">
    <div class="card-header"><span class="card-title">Items to Pick Up</span></div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Return</th><th>Buyer / Address</th><th>Item</th><th>Action</th></tr></thead>
        <tbody>
        @foreach($pickups as $pickup)
            @php $delivery = $pickup->order->delivery; @endphp
            <tr>
                <td><strong>#{{ $pickup->id }}</strong><div style="font-size:0.75rem;color:#888;">{{ $pickup->order->order_number }}</div></td>
                <td><strong>{{ $delivery['name'] ?? '—' }}</strong><div style="font-size:0.78rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div><div style="font-size:0.75rem;color:#888;">{{ $delivery['phone'] ?? '' }}</div></td>
                <td>{{ $pickup->quantity }} × {{ $pickup->order->product_name }}<div style="font-size:0.75rem;color:#888;">No cash changes hands on pickup.</div></td>
                <td><form method="POST" action="{{ route('courier.returns.pickup', $pickup) }}">@csrf<button class="btn btn-success" type="submit">Item Collected</button></form></td>
            </tr>
        @endforeach
        </tbody>
    </table></div>
</div>
@endif

@if($refunds->isNotEmpty())
<div class="card">
    <div class="card-header"><span class="card-title">Refunds to Hand Over</span></div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>Return</th><th>Recipient / Address</th><th>Refund</th><th>Action</th></tr></thead>
            <tbody>
            @foreach($refunds as $refund)
                @php
                    $delivery = $refund->order->delivery;
                    $amount = $refund->resolutionCents();
                    $collectsItem = $refund->requires_item_return && $refund->refund_timing === 'on_pickup' && !$refund->item_collected_at;
                @endphp
                <tr>
                    <td><strong>#{{ $refund->id }}</strong><div style="font-size:0.75rem;color:#888;">{{ $refund->order->order_number }}</div></td>
                    <td>
                        <strong>{{ $delivery['name'] ?? '—' }}</strong>
                        <div style="font-size:0.78rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div>
                        <div style="font-size:0.75rem;color:#888;">{{ $delivery['phone'] ?? '' }}</div>
                    </td>
                    <td><strong>{{ Money::format($amount) }}</strong>@if($collectsItem)<div style="font-size:0.75rem;color:#b45309;">Collect {{ $refund->quantity }} item(s) back</div>@endif</td>
                    <td>
                        <form method="POST" action="{{ route('courier.refunds.handover', $refund) }}" onsubmit="return confirm('Confirm you handed {{ Money::format($amount) }} to the buyer?')">
                            @csrf
                            <input type="hidden" name="amount" value="{{ Money::pesos($amount) }}">
                            @if($collectsItem)
                                <label style="font-size:0.78rem;display:block;margin-bottom:0.3rem;"><input type="checkbox" name="item_collected" value="1" required> Item collected</label>
                            @endif
                            <button class="btn btn-success" type="submit">Refund Handed Over</button>
                        </form>
                        <div style="font-size:0.72rem;color:#888;margin-top:0.3rem;">Couldn't hand it over? Return the cash to the sorting center.</div>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
</div>
@endif

<div class="card">
    <div class="card-header">
        <span class="card-title">Assigned Parcels</span>
        <form method="GET"><select name="status" class="filter-select" onchange="this.form.submit()">
            <option value="all" {{ $status === 'all' ? 'selected' : '' }}>All</option>
            <option value="shipped" {{ $status === 'shipped' ? 'selected' : '' }}>Out for Delivery</option>
            <option value="completed" {{ $status === 'completed' ? 'selected' : '' }}>Delivered</option>
        </select></form>
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>Parcel</th><th>Recipient / Address</th><th>Seller</th><th>Status</th><th>Action</th></tr></thead>
            <tbody>
            @forelse($orders as $order)
            @php
                $delivery = $order->delivery;
                $state = $order->canonical_status;
                $label = match ($state) {
                    OrderStatus::ASSIGNED_TO_RIDER => 'Assigned',
                    OrderStatus::OUT_FOR_DELIVERY  => 'Out for delivery',
                    OrderStatus::DELIVERY_FAILED   => 'Delivery failed',
                    OrderStatus::RETURNED          => 'Returned to seller',
                    default                        => ucfirst($order->status),
                };
                $maxAttempts = (int) config('picksell.delivery.max_attempts');
            @endphp
            <tr>
                <td><strong>{{ $order->order_number }}</strong><div style="font-size:0.75rem;color:#888;">{{ $order->waybill_number ?? 'No waybill' }}</div></td>
                <td>
                    <strong>{{ $delivery['name'] ?? '—' }}</strong>
                    <div style="font-size:0.78rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div>
                    @if($delivery['landmark'])<div style="font-size:0.75rem;color:#888;">Landmark: {{ $delivery['landmark'] }}</div>@endif
                    <div style="font-size:0.75rem;color:#888;">{{ $delivery['phone'] ?? '' }}</div>
                </td>
                <td>{{ $order->seller->business_name ?? $order->seller->full_name ?? '—' }}</td>
                <td><span class="badge badge-{{ $order->status }}">{{ $label }}</span><div style="font-size:0.75rem;color:#888;margin-top:0.2rem;">{{ $order->tracking_status ?? 'Assigned' }}</div>
                    @if($order->delivery_attempts && $order->status === 'shipped')<div style="font-size:0.72rem;color:#888;">Attempts: {{ $order->delivery_attempts }} of {{ $maxAttempts }}</div>@endif</td>
                <td>
                    @if(OrderStatus::can($order, 'out_for_delivery') && $order->delivery_attempts < $maxAttempts)
                    <form method="POST" action="{{ route('courier.orders.status', $order) }}">@csrf @method('PATCH')<input type="hidden" name="status" value="shipped"><button class="btn btn-coral" type="submit">{{ $state === OrderStatus::DELIVERY_FAILED ? 'Try Again' : 'Out for Delivery' }}</button></form>
                    @elseif(OrderStatus::can($order, 'deliver'))
                    @php $due = $order->totalCents(); @endphp
                    <form method="POST" action="{{ route('courier.orders.status', $order) }}" enctype="multipart/form-data" style="display:flex;flex-direction:column;gap:0.3rem;">@csrf @method('PATCH')
                        <input type="hidden" name="status" value="completed">
                        <label style="font-size:0.75rem;color:#888;">Cash collected (COD {{ Money::format($due) }})</label>
                        <input type="number" name="cash_collected" step="0.01" min="0" value="{{ Money::pesos($due) }}" required style="width:120px;padding:0.3rem;border:1.5px solid #ddd6c8;border-radius:6px;">
                        <label style="font-size:0.75rem;color:#888;">Received by</label>
                        <input type="text" name="recipient_name" value="{{ $delivery['name'] }}" required maxlength="120" style="width:160px;padding:0.3rem;border:1.5px solid #ddd6c8;border-radius:6px;">
                        <label style="font-size:0.75rem;color:#888;">Proof photo (optional)</label>
                        <input type="file" name="proof_photo" accept="image/*" style="font-size:0.75rem;max-width:180px;">
                        <button class="btn btn-success" type="submit">Mark Delivered</button>
                    </form>
                    <form method="POST" action="{{ route('courier.orders.fail', $order) }}" style="display:flex;flex-direction:column;gap:0.3rem;margin-top:0.5rem;">@csrf
                        <select name="reason" class="filter-select" required>
                            <option value="">Delivery failed because…</option>
                            @foreach($failedReasons as $reason)<option value="{{ $reason }}">{{ $reason }}</option>@endforeach
                        </select>
                        <button class="btn btn-outline" type="submit">Record Failed Attempt</button>
                    </form>
                    @elseif($state === OrderStatus::DELIVERY_FAILED)
                    <span style="color:#b45309;font-size:0.8rem;">Max attempts reached — bring it back to the sorting center.</span>
                    @elseif($order->status === 'completed')
                    <span style="color:#16a34a;font-size:0.8rem;">Completed {{ $order->delivered_at?->forDisplay()->format('M d, Y') }}</span>
                    @endif
                </td>
            </tr>
            @empty
            <tr><td colspan="5" style="text-align:center;color:#888;padding:2rem;">No parcels assigned to you yet.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($orders->hasPages())<div class="dashboard-pagination">{{ $orders->withQueryString()->links() }}</div>@endif
</div>
@endsection
