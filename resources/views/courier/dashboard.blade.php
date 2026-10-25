@extends('courier.layout')
@section('title', 'Delivery Tasks')
@section('content')
<h1 style="margin:0 0 0.3rem;font-size:1.45rem;">Delivery Tasks</h1>
<p style="color:#888;margin:0 0 1.2rem;">Assigned area: <strong style="color:#2d2d2d;">{{ auth()->user()->delivery_area ?? 'Area not set' }}</strong></p>

<div class="stats">
    <div class="stat"><strong>{{ $stats['assigned'] }}</strong><span>Active Assignments</span></div>
    <div class="stat"><strong>{{ $stats['in_transit'] }}</strong><span>Out for Delivery</span></div>
    <div class="stat"><strong>{{ $stats['delivered'] }}</strong><span>Delivered</span></div>
    <div class="stat"><strong>{{ \App\Support\Money::format($stats['earnings']) }}</strong><span>Settled Rider Pay</span></div>
    <div class="stat"><strong>{{ \App\Support\Money::format($stats['cash_on_hand']) }}</strong><span>Cash to Hand In</span></div>
</div>

@if($refunds->isNotEmpty())
<div class="card">
    <div class="card-header"><span class="card-title">Refunds to Hand Over</span></div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>Return</th><th>Recipient / Address</th><th>Refund</th><th>Action</th></tr></thead>
            <tbody>
            @foreach($refunds as $refund)
                @php $delivery = $refund->order->delivery; $amount = $refund->resolutionCents(); @endphp
                <tr>
                    <td><strong>#{{ $refund->id }}</strong><div style="font-size:0.75rem;color:#888;">{{ $refund->order->order_number }}</div></td>
                    <td>
                        <strong>{{ $delivery['name'] ?? '—' }}</strong>
                        <div style="font-size:0.78rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div>
                        <div style="font-size:0.75rem;color:#888;">{{ $delivery['phone'] ?? '' }}</div>
                    </td>
                    <td><strong>{{ \App\Support\Money::format($amount) }}</strong>@if($refund->requires_item_return)<div style="font-size:0.75rem;color:#b45309;">Collect {{ $refund->quantity }} item(s) back</div>@endif</td>
                    <td>
                        <form method="POST" action="{{ route('courier.refunds.handover', $refund) }}" onsubmit="return confirm('Confirm you handed {{ \App\Support\Money::format($amount) }} to the buyer?')">
                            @csrf
                            <input type="hidden" name="amount" value="{{ \App\Support\Money::pesos($amount) }}">
                            @if($refund->requires_item_return)
                                <label style="font-size:0.78rem;display:block;margin-bottom:0.3rem;"><input type="checkbox" name="item_collected" value="1" required> Item collected</label>
                            @endif
                            <button class="btn btn-success" type="submit">Refund Handed Over</button>
                        </form>
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
            <tr>
                <td><strong>{{ $order->order_number }}</strong><div style="font-size:0.75rem;color:#888;">{{ $order->waybill_number ?? 'No waybill' }}</div></td>
                @php $delivery = $order->delivery; @endphp
                <td>
                    <strong>{{ $delivery['name'] ?? '—' }}</strong>
                    <div style="font-size:0.78rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div>
                    @if($delivery['landmark'])<div style="font-size:0.75rem;color:#888;">Landmark: {{ $delivery['landmark'] }}</div>@endif
                    <div style="font-size:0.75rem;color:#888;">{{ $delivery['phone'] ?? '' }}</div>
                </td>
                <td>{{ $order->seller->business_name ?? $order->seller->full_name ?? '—' }}</td>
                <td><span class="badge badge-{{ $order->status }}">{{ $order->canonical_status === \App\Support\OrderStatus::ASSIGNED_TO_RIDER ? 'Assigned' : ($order->status === 'shipped' ? 'Out for delivery' : ucfirst($order->status)) }}</span><div style="font-size:0.75rem;color:#888;margin-top:0.2rem;">{{ $order->tracking_status ?? 'Assigned' }}</div></td>
                <td>
                    @if(\App\Support\OrderStatus::can($order, 'out_for_delivery'))
                    <form method="POST" action="{{ route('courier.orders.status', $order) }}">@csrf @method('PATCH')<input type="hidden" name="status" value="shipped"><button class="btn btn-coral" type="submit">Out for Delivery</button></form>
                    @elseif(\App\Support\OrderStatus::can($order, 'deliver'))
                    @php $due = $order->totalCents(); @endphp
                    <form method="POST" action="{{ route('courier.orders.status', $order) }}" style="display:flex;flex-direction:column;gap:0.3rem;">@csrf @method('PATCH')
                        <input type="hidden" name="status" value="completed">
                        <label style="font-size:0.75rem;color:#888;">Cash collected (COD {{ \App\Support\Money::format($due) }})</label>
                        <input type="number" name="cash_collected" step="0.01" min="0" value="{{ \App\Support\Money::pesos($due) }}" required style="width:120px;padding:0.3rem;border:1.5px solid #ddd6c8;border-radius:6px;">
                        <button class="btn btn-success" type="submit">Mark Delivered</button>
                    </form>
                    @elseif($order->status === 'completed')
                    <span style="color:#16a34a;font-size:0.8rem;">Completed {{ optional($order->delivered_at)->format('M d, Y') }}</span>
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
