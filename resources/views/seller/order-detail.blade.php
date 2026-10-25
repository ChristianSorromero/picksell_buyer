@extends('seller.layout')
@section('title', 'Order #' . $order->order_number)

@section('content')
<div style="margin-bottom:1rem;">
    <a href="/seller/orders" class="btn btn-outline btn-sm">← Back to Orders</a>
</div>

<div class="grid-2">
    <div>
        <div class="card">
            <div class="card-header">
                <span class="card-title">Order Details</span>
                <span class="badge badge-{{ $order->status }}">{{ $order->status }}</span>
            </div>
            <div class="card-body">
                <table>
                    <tr><td style="color:#888;width:140px;">Order #</td><td><strong>{{ $order->order_number }}</strong></td></tr>
                    <tr><td style="color:#888;">Product</td><td>{{ $order->product_name }}</td></tr>
                    <tr><td style="color:#888;">Quantity</td><td>{{ $order->quantity }}</td></tr>
                    <tr><td style="color:#888;">Amount</td><td><strong>₱{{ number_format($order->amount, 2) }}</strong></td></tr>
                    <tr><td style="color:#888;">Commission</td><td>₱{{ number_format($order->commission, 2) }}</td></tr>
                    <tr><td style="color:#888;">Net Profit</td><td><strong style="color:#16a34a;">₱{{ number_format($order->amount - $order->commission, 2) }}</strong></td></tr>
                    <tr><td style="color:#888;">Order Date</td><td>{{ $order->created_at->forDisplay()->format('M d, Y h:i A') }}</td></tr>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-header"><span class="card-title">Buyer Information</span></div>
            <div class="card-body">
                @if($order->buyer)
                <table>
                    <tr><td style="color:#888;width:140px;">Name</td><td>{{ $order->buyer->full_name }}</td></tr>
                    <tr><td style="color:#888;">Email</td><td>{{ $order->buyer->email }}</td></tr>
                </table>
                @else
                <p style="color:#aaa;">Buyer info unavailable.</p>
                @endif
            </div>
        </div>

        @php $delivery = $order->delivery; @endphp
        <div class="card">
            <div class="card-header"><span class="card-title">Deliver To</span></div>
            <div class="card-body">
                <table>
                    <tr><td style="color:#888;width:140px;">Recipient</td><td>{{ $delivery['name'] ?? '—' }}</td></tr>
                    <tr><td style="color:#888;">Contact</td><td>{{ $delivery['phone'] ?? '—' }}</td></tr>
                    <tr><td style="color:#888;">Address</td><td>{{ $delivery['address'] ?? 'Address unavailable' }}</td></tr>
                    @if($delivery['landmark'])
                    <tr><td style="color:#888;">Landmark</td><td>{{ $delivery['landmark'] }}</td></tr>
                    @endif
                </table>
            </div>
        </div>
    </div>

    <div>
        <div class="card">
            <div class="card-header"><span class="card-title">Shipment & Tracking</span></div>
            <div class="card-body">
                <table>
                    <tr><td style="color:#888;width:140px;">Waybill #</td><td>{{ $order->waybill_number ?? '—' }}</td></tr>
                    <tr><td style="color:#888;">Tracking Status</td><td>{{ $order->tracking_status ?? '—' }}</td></tr>
                    <tr><td style="color:#888;">Packed At</td><td>{{ $order->packed_at ? $order->packed_at->forDisplay()->format('M d, Y h:i A') : '—' }}</td></tr>
                    <tr><td style="color:#888;">Handed Over</td><td>{{ $order->handed_over_at ? $order->handed_over_at->forDisplay()->format('M d, Y h:i A') : '—' }}</td></tr>
                    <tr><td style="color:#888;">Delivered At</td><td>{{ $order->delivered_at ? $order->delivered_at->forDisplay()->format('M d, Y h:i A') : '—' }}</td></tr>
                </table>

                <div style="margin-top:1.2rem;">
                    @if($order->status === 'pending')
                    <form method="POST" action="/seller/orders/{{ $order->id }}/pack">
                        @csrf @method('PATCH')
                        <button type="submit" class="btn btn-coral">Mark as Packed</button>
                    </form>
                    @elseif($order->status === 'processing')
                    <form method="POST" action="/seller/orders/{{ $order->id }}/handover" style="display:flex;gap:0.5rem;align-items:flex-end;">
                        @csrf @method('PATCH')
                        <div class="form-group" style="flex:1;margin:0;">
                            <label class="form-label">Waybill Number *</label>
                            <input type="text" name="waybill_number" class="form-control" required placeholder="Enter waybill number">
                        </div>
                        <button type="submit" class="btn btn-success">Hand Over</button>
                    </form>
                    @elseif(\App\Support\OrderStatus::can($order, 'receive_returned') && $order->status === 'shipped')
                    <div class="alert alert-error" style="margin:0 0 0.6rem;">Delivery failed {{ $order->delivery_attempts }} time(s); the parcel is being returned to you. The buyer was not charged.</div>
                    <form method="POST" action="{{ route('seller.orders.returned', $order) }}" style="display:flex;gap:0.5rem;flex-wrap:wrap;">
                        @csrf
                        <button name="restock" value="1" class="btn btn-success">Parcel received — put back in stock</button>
                        <button name="restock" value="0" class="btn btn-outline">Parcel received — don't restock</button>
                    </form>
                    @elseif($order->canonical_status === \App\Support\OrderStatus::RETURNED)
                    <div class="alert alert-success" style="margin:0;">Returned parcel received{{ $order->auditLogs()->where('action', 'returned_parcel_restocked')->exists() ? ' and restocked' : '' }}.</div>
                    @elseif($order->status === 'shipped')
                    <div class="alert alert-success" style="margin:0;">Order has been handed over to courier. {{ $order->canonical_status === \App\Support\OrderStatus::DELIVERY_FAILED ? 'A delivery attempt failed: ' . \Illuminate\Support\Str::after($order->tracking_status, 'Delivery failed: ') : 'Awaiting delivery confirmation.' }}</div>
                    @elseif($order->status === 'completed')
                    <div class="alert alert-success" style="margin:0;">Order delivered and completed.</div>
                    @endif
                </div>
            </div>
        </div>

        @if($order->status === 'completed' && ($order->rating || $order->feedback))
        <div class="card">
            <div class="card-header"><span class="card-title">Customer Feedback</span></div>
            <div class="card-body">
                @if($order->rating)
                <div style="margin-bottom:0.5rem;font-size:0.85rem;color:#888;">Customer rating: {{ $order->rating }}/5</div>
                @endif
                @if($order->feedback)
                <p style="font-size:0.88rem;color:#555;">{{ $order->feedback }}</p>
                @endif
            </div>
        </div>
        @endif
    </div>
</div>
@endsection
