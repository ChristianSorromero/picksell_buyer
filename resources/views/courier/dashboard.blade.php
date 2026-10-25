@extends('courier.layout')
@section('title', 'Delivery Tasks')
@section('content')
<h1 style="margin:0 0 0.3rem;font-size:1.45rem;">Delivery Tasks</h1>
<p style="color:#888;margin:0 0 1.2rem;">Assigned area: <strong style="color:#2d2d2d;">{{ auth()->user()->delivery_area ?? 'Area not set' }}</strong></p>

<div class="stats">
    <div class="stat"><strong>{{ $stats['assigned'] }}</strong><span>Active Assignments</span></div>
    <div class="stat"><strong>{{ $stats['in_transit'] }}</strong><span>Out for Delivery</span></div>
    <div class="stat"><strong>{{ $stats['delivered'] }}</strong><span>Delivered</span></div>
    <div class="stat"><strong>₱{{ number_format($stats['earnings'], 2) }}</strong><span>Completed Commission</span></div>
</div>

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
                    <form method="POST" action="{{ route('courier.orders.status', $order) }}">@csrf @method('PATCH')<input type="hidden" name="status" value="completed"><button class="btn btn-success" type="submit">Mark Delivered</button></form>
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
