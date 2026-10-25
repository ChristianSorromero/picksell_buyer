@extends('seller.layout')
@section('title', 'Dashboard')

@section('content')
<div class="stat-grid">
    <div class="stat-card coral">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M20 6h-2.18c.07-.44.18-.88.18-1.36C18 2.06 15.94 0 13.36 0c-1.3 0-2.48.52-3.36 1.36C9.12.52 7.94 0 6.64 0 4.06 0 2 2.06 2 4.64c0 .48.11.92.18 1.36H0v14c0 1.1.9 2 2 2h20c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 14H4V8h16v10z"/></svg>
        </div>
        <div class="stat-card-num">{{ $stats['total_orders'] }}</div>
        <div class="stat-card-label">Total Orders</div>
    </div>
    <div class="stat-card orange">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
        </div>
        <div class="stat-card-num">{{ $stats['pending_orders'] }}</div>
        <div class="stat-card-label">Pending Orders</div>
    </div>
    <div class="stat-card green">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
        </div>
        <div class="stat-card-num">{{ $stats['completed_orders'] }}</div>
        <div class="stat-card-label">Completed Orders</div>
    </div>
    <div class="stat-card blue">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16c-1.94.42-3.5 1.68-3.5 3.61 0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1h-2.2c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/></svg>
        </div>
        <div class="stat-card-num">₱{{ number_format($stats['total_sales'], 2) }}</div>
        <div class="stat-card-label">Total Sales</div>
    </div>
    <div class="stat-card">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M19 6H5c-1.1 0-2 .9-2 2v9c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 11H5V8h14v9zM5 4h14v1H5zm2-2h10v1H7z"/></svg>
        </div>
        <div class="stat-card-num">{{ $stats['total_products'] }}</div>
        <div class="stat-card-label">Active Products</div>
    </div>
    <div class="stat-card red">
        <div class="stat-card-icon">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" viewBox="0 0 24 24"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>
        </div>
        <div class="stat-card-num">{{ $stats['low_stock'] }}</div>
        <div class="stat-card-label">Low Stock Items</div>
    </div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Monthly Sales (Last 6 Months)</span></div>
        <div class="card-body"><div id="salesChart"></div></div>
    </div>
    <div class="card">
        <div class="card-header">
            <span class="card-title">Recent Orders</span>
            <a href="/seller/orders" class="btn btn-outline btn-sm">View All</a>
        </div>
        <div class="card-body" style="padding:0;">
            @if($recentOrders->isEmpty())
                <div style="padding:1.5rem;text-align:center;color:#aaa;font-size:0.85rem;">No orders yet.</div>
            @else
            <table>
                <thead><tr><th>Order #</th><th>Buyer</th><th>Amount</th><th>Status</th></tr></thead>
                <tbody>
                @foreach($recentOrders as $order)
                <tr>
                    <td><a href="/seller/orders/{{ $order->id }}" style="color:var(--coral);font-weight:600;">{{ $order->order_number }}</a></td>
                    <td>{{ $order->buyer->full_name ?? '—' }}</td>
                    <td>₱{{ number_format($order->amount, 2) }}</td>
                    <td><span class="badge badge-{{ $order->status }}">{{ \App\Support\OrderStatus::staffLabel($order) }}</span></td>
                </tr>
                @endforeach
                </tbody>
            </table>
            @endif
        </div>
    </div>
</div>
@endsection

@section('scripts')
<script>
new ApexCharts(document.getElementById('salesChart'), {
    chart: { type: 'area', height: 220, toolbar: { show: false }, sparkline: { enabled: false } },
    series: [{ name: 'Sales (₱)', data: {!! json_encode($sales) !!} }],
    xaxis: { categories: {!! json_encode($months) !!} },
    colors: ['#E8472A'],
    fill: { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.4, opacityTo: 0.05 } },
    stroke: { curve: 'smooth', width: 2 },
    dataLabels: { enabled: false },
    yaxis: { labels: { formatter: v => '₱' + v.toLocaleString() } },
    tooltip: { y: { formatter: v => '₱' + v.toLocaleString() } },
    grid: { borderColor: '#f0ebe0' },
}).render();
</script>
@endsection
