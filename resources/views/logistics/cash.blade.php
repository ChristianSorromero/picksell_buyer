@extends('logistics.layout')
@section('title', 'Cash Desk')

@section('content')
@use('App\Support\Money')
<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">COD Hand-ins</span>
            <div style="font-size:.78rem;color:#888;margin-top:.25rem;">Count the cash a rider hands in, then confirm the parcels it covers. Confirmed orders are marked paid.</div>
        </div>
    </div>
    <div style="padding:1rem;">
        @forelse($awaiting as $courierId => $orders)
            @php $rider = $riders[$courierId]; @endphp
            <form method="POST" action="{{ route('logistics.cash.remit', $rider) }}" style="border:1px solid #eee;border-radius:10px;padding:.8rem;margin-bottom:.8rem;">
                @csrf
                <strong>{{ $rider->full_name }}</strong> · holding {{ Money::format($riderCash[$courierId] ?? 0) }}
                <table style="margin-top:.5rem;">
                    <thead><tr><th></th><th>Parcel</th><th>Collected</th><th>Amount</th></tr></thead>
                    <tbody>
                    @foreach($orders as $order)
                        <tr>
                            <td><input type="checkbox" name="order_ids[]" value="{{ $order->id }}" checked></td>
                            <td>{{ $order->order_number }}</td>
                            <td>{{ $order->cod_collected_at->format('M d, h:i A') }}</td>
                            <td>{{ Money::format($order->totalCents()) }}</td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
                <button class="btn btn-coral" style="margin-top:.5rem;" onclick="return confirm('Confirm you counted and received this cash from {{ $rider->full_name }}?')">Confirm cash received</button>
            </form>
        @empty
            <p style="color:#888;text-align:center;">No COD cash waiting to be handed in.</p>
        @endforelse
    </div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Return Pickups</span></div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Return</th><th>Buyer / Address</th><th>Status</th><th>Assign rider</th></tr></thead>
        <tbody>
        @forelse($pickups as $r)
            <tr>
                <td>#{{ $r->id }}<div style="font-size:.72rem;color:#888;">{{ $r->order->order_number }} · {{ $r->quantity }} item(s)</div></td>
                <td>{{ $r->order->delivery['name'] ?? '—' }}<div style="font-size:.75rem;color:#888;">{{ $r->order->delivery['address'] ?? '' }}</div></td>
                <td>{{ $r->pickupCourier ? 'Assigned to ' . $r->pickupCourier->full_name : 'Not assigned' }}<div style="font-size:.72rem;color:#888;">Item goes to the seller for inspection; no cash on pickup.</div></td>
                <td>
                    <form method="POST" action="{{ route('logistics.returns.pickup', $r) }}" style="display:flex;gap:.4rem;">
                        @csrf
                        <select name="courier_id" class="filter-select" required>
                            <option value="">Choose rider</option>
                            @foreach($couriers as $courier)<option value="{{ $courier->id }}">{{ $courier->full_name }} — {{ $courier->delivery_area ?? 'Area not set' }}</option>@endforeach
                        </select>
                        <button class="btn btn-outline">{{ $r->pickupCourier ? 'Reassign' : 'Assign pickup' }}</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="4" style="text-align:center;color:#888;padding:1.5rem;">No items waiting for pickup.</td></tr>
        @endforelse
        </tbody>
    </table></div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Refunds to Send Out</span></div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Return</th><th>Buyer / Address</th><th>Refund</th><th>Give cash to rider</th></tr></thead>
        <tbody>
        @forelse($refundsToSend as $r)
            <tr>
                <td>#{{ $r->id }}<div style="font-size:.72rem;color:#888;">{{ $r->order->order_number }}</div></td>
                <td>{{ $r->order->delivery['name'] ?? '—' }}<div style="font-size:.75rem;color:#888;">{{ $r->order->delivery['address'] ?? '' }}</div></td>
                @php $blocker = $r->refundBlocker(); @endphp
                <td><strong>{{ Money::format($r->resolutionCents()) }}</strong>
                    @if($r->refund_timing === 'on_pickup' && !$r->item_collected_at)<div style="font-size:.72rem;color:#b45309;">Expedited: rider collects the item on the same visit</div>@endif
                    @if($blocker)<div style="font-size:.72rem;color:#dc2626;">{{ $blocker }}</div>@endif</td>
                <td>
                    @if(!$blocker)
                    <form method="POST" action="{{ route('logistics.refunds.release', $r) }}" style="display:flex;gap:.4rem;">
                        @csrf
                        <select name="courier_id" class="filter-select" required>
                            <option value="">Choose rider</option>
                            @foreach($couriers as $courier)<option value="{{ $courier->id }}">{{ $courier->full_name }} — {{ $courier->delivery_area ?? 'Area not set' }}</option>@endforeach
                        </select>
                        <button class="btn btn-coral">Release cash</button>
                    </form>
                    @else
                    <span style="font-size:.78rem;color:#888;">Not yet</span>
                    @endif
                </td>
            </tr>
        @empty
            <tr><td colspan="4" style="text-align:center;color:#888;padding:1.5rem;">No approved refunds waiting.</td></tr>
        @endforelse
        </tbody>
    </table></div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Refund Cash With Riders</span></div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Return</th><th>Rider</th><th>Amount</th><th>Released</th><th>Brought back?</th></tr></thead>
        <tbody>
        @forelse($refundsOut as $r)
            <tr>
                <td>#{{ $r->id }}</td>
                <td>{{ $r->refundCourier->full_name ?? '—' }}</td>
                <td>{{ Money::format($r->resolutionCents()) }}</td>
                <td>{{ $r->refund_released_at->format('M d, h:i A') }}</td>
                <td>
                    <form method="POST" action="{{ route('logistics.refunds.cancel', $r) }}" style="display:flex;gap:.4rem;">
                        @csrf
                        <input type="text" name="reason" class="form-control" placeholder="Why (e.g. buyer not home)" required style="width:180px;">
                        <button class="btn btn-outline">Cash returned</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="5" style="text-align:center;color:#888;padding:1.5rem;">No refund cash out with riders.</td></tr>
        @endforelse
        </tbody>
    </table></div>
</div>
@endsection
