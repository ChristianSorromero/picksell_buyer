@extends('admin.layout')
@section('title', 'Commission Management')

@section('content')
<!-- Date Filter -->
<div class="card" style="margin-bottom:1.5rem;">
    <div class="card-body">
        <form method="GET" style="display:flex;gap:1rem;align-items:flex-end;flex-wrap:wrap;">
            <div class="form-group" style="margin:0;">
                <label class="form-label">From</label>
                <input type="date" name="from" class="form-control" value="{{ $from }}" style="width:160px;">
            </div>
            <div class="form-group" style="margin:0;">
                <label class="form-label">To</label>
                <input type="date" name="to" class="form-control" value="{{ $to }}" style="width:160px;">
            </div>
            <button type="submit" class="btn btn-coral">Filter</button>
        </form>
    </div>
</div>

<div class="stat-grid">
    <div class="stat-card green">
        <div class="stat-card-icon">💰</div>
        <div class="stat-card-num">₱{{ number_format($totalSales, 2) }}</div>
        <div class="stat-card-label">Total Sales</div>
    </div>
    <div class="stat-card coral">
        <div class="stat-card-icon">📊</div>
        <div class="stat-card-num">₱{{ number_format($totalCommission, 2) }}</div>
        <div class="stat-card-label">Total Commission ({{ $rate }}%)</div>
    </div>
    <div class="stat-card blue">
        <div class="stat-card-icon">🧾</div>
        <div class="stat-card-num">{{ $orders->count() }}</div>
        <div class="stat-card-label">Completed Orders</div>
    </div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Commission by Seller</span></div>
        <div class="card-body"><div id="commissionChart"></div></div>
    </div>
    <div class="card">
        <div class="card-header"><span class="card-title">Commission Rate</span></div>
        <div class="card-body">
            <p style="font-size:0.88rem;color:#555;margin-bottom:1rem;">Current platform commission rate applied to all completed orders.</p>
            <div style="font-size:3rem;font-weight:800;color:var(--coral);text-align:center;padding:1.5rem 0;">{{ $rate }}%</div>
            <p style="font-size:0.82rem;color:#aaa;text-align:center;">Per completed transaction</p>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Order Commission Breakdown</span></div>
    @if($orders->isEmpty())
    <div class="card-body" style="color:#888;font-size:0.88rem;">No completed orders in this period.</div>
    @else
    <table>
        <thead>
            <tr><th>Order #</th><th>Seller</th><th>Product</th><th>Order Amount</th><th>Commission ({{ $rate }}%)</th><th>Date</th></tr>
        </thead>
        <tbody>
        @foreach($orders as $order)
        <tr>
            <td><strong>{{ $order->order_number }}</strong></td>
            <td>{{ $order->seller->full_name ?? '—' }}</td>
            <td>{{ $order->product_name }}</td>
            <td>₱{{ number_format($order->amount, 2) }}</td>
            <td style="color:var(--coral);font-weight:700;">₱{{ number_format($order->commission, 2) }}</td>
            <td>{{ $order->created_at->forDisplay()->format('M d, Y') }}</td>
        </tr>
        @endforeach
        </tbody>
    </table>
    @endif
</div>

<script>
@if($orders->isNotEmpty())
new ApexCharts(document.getElementById('commissionChart'), {
    chart: { type: 'bar', height: 280, toolbar: { show: false } },
    series: [{ name: 'Commission (₱)', data: [{{ $orders->pluck('commission')->implode(',') }}] }],
    xaxis: { categories: [{{ $orders->map(fn($o) => '"'.addslashes($o->order_number).'"')->implode(',') }}] },
    colors: ['#E8472A'],
    dataLabels: { enabled: false },
    plotOptions: { bar: { borderRadius: 4 } },
}).render();
@else
document.getElementById('commissionChart').innerHTML = '<p style="text-align:center;color:#aaa;padding:2rem;">No data available</p>';
@endif
</script>
@endsection
