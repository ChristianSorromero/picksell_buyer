@extends('admin.layout')
@section('title', 'Sorting Center / Logistics')

@section('content')
<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Sorting Center / Logistics</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.25rem;">Receive, scan, sort, and assign prepared parcels to riders.</div>
        </div>
        <form method="GET">
            <select name="status" class="filter-select" onchange="this.form.submit()">
                <option value="all" {{ $status === 'all' ? 'selected' : '' }}>All Parcels</option>
                <option value="shipped" {{ $status === 'shipped' ? 'selected' : '' }}>At Sorting Center / In Transit</option>
                <option value="completed" {{ $status === 'completed' ? 'selected' : '' }}>Delivered</option>
            </select>
        </form>
    </div>
    <div style="padding:1rem 1.2rem;background:#fff8e1;border-bottom:1px solid #f0ebe0;font-size:0.84rem;">
        <strong>Process:</strong> Receive parcel → Scan waybill → Read address → Determine area → Sort parcel → Identify rider → Assign parcel.
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead>
                <tr><th>Parcel / Waybill</th><th>Delivery Address / Area</th><th>Seller</th><th>Status</th><th>Assigned Rider</th><th>Action</th></tr>
            </thead>
            <tbody>
            @forelse($orders as $order)
                @php
                    $delivery = $order->delivery;
                    $area = $delivery['area'];
                @endphp
                <tr>
                    <td>
                        <strong>{{ $order->order_number }}</strong>
                        <div style="font-size:0.75rem;color:#888;">{{ $order->waybill_number ?? 'Awaiting scan / waybill' }}</div>
                    </td>
                    <td>
                        <div>{{ $area }}</div>
                        <div style="font-size:0.75rem;color:#888;">{{ $delivery['address'] ?? 'Address unavailable' }}</div>
                    </td>
                    <td>{{ $order->seller->business_name ?? $order->seller->full_name ?? '—' }}</td>
                    <td>
                        <span class="badge badge-{{ $order->status }}">{{ ucfirst($order->status) }}</span>
                        <div style="font-size:0.72rem;color:#888;margin-top:0.25rem;max-width:180px;">{{ $order->tracking_status ?? 'Received from seller' }}</div>
                    </td>
                    <td>
                        @if($order->courier)
                            <strong>{{ $order->courier->full_name }}</strong>
                            <div style="font-size:0.75rem;color:#888;">{{ $order->courier->delivery_area ?? 'Area not set' }}</div>
                        @else
                            <span style="color:#b45309;">Unassigned</span>
                        @endif
                    </td>
                    <td>
                        @if($order->status !== 'completed')
                        <div style="display:flex;gap:0.4rem;flex-wrap:wrap;min-width:280px;">
                        @if(\App\Support\OrderStatus::can($order, 'return_to_sender'))
                        <form method="POST" action="{{ route('admin.logistics.rts', $order) }}" style="display:flex;gap:0.4rem;">
                            @csrf
                            <input type="text" name="reason" class="form-control" placeholder="Why" required style="width:150px;">
                            <button class="btn btn-outline btn-sm" type="submit">Return to seller</button>
                        </form>
                        @endif
                        @if(\App\Support\OrderStatus::can($order, 'scan'))
                        <form method="POST" action="{{ route('admin.logistics.scan', $order) }}">
                            @csrf @method('PATCH')
                            <button class="btn btn-outline btn-sm" type="submit">Mark Scanned</button>
                        </form>
                        @endif
                        @if(\App\Support\OrderStatus::can($order, 'assign'))
                        <form method="POST" action="{{ route('admin.logistics.assign', $order) }}" style="display:flex;gap:0.4rem;">
                            @csrf @method('PATCH')
                            <select name="courier_id" class="filter-select" required>
                                <option value="">Assign rider</option>
                                @foreach($couriers as $courier)
                                <option value="{{ $courier->id }}" {{ $order->courier_id === $courier->id ? 'selected' : '' }}>
                                    {{ $courier->full_name }} — {{ $courier->delivery_area ?? 'Area not set' }}
                                </option>
                                @endforeach
                            </select>
                            <button class="btn btn-coral btn-sm" type="submit">Assign</button>
                        </form>
                        @endif
                            </div>
                        @else
                            <span style="font-size:0.8rem;color:#16a34a;">Completed</span>
                        @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="6" style="text-align:center;color:#888;padding:2rem;">No parcels found.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($orders->hasPages())
    <div class="dashboard-pagination">{{ $orders->withQueryString()->links() }}</div>
    @endif
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Approved Rider Areas</span></div>
    <div class="card-body">
        @forelse($couriers->groupBy(fn($courier) => $courier->delivery_area ?: 'Area not set') as $area => $areaCouriers)
            <div style="display:inline-flex;flex-direction:column;gap:0.2rem;padding:0.7rem 1rem;margin:0 0.6rem 0.6rem 0;border:1px solid #e8e2d8;border-radius:8px;min-width:180px;">
                <strong>{{ $area }}</strong>
                <span style="font-size:0.78rem;color:#888;">{{ $areaCouriers->pluck('full_name')->join(', ') }}</span>
            </div>
        @empty
            <span style="color:#888;">No approved riders yet.</span>
        @endforelse
    </div>
</div>
@endsection
