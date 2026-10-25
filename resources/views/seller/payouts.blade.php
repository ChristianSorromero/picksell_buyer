@extends('seller.layout')
@section('title', 'Payouts')

@section('content')
@use('App\Support\Money')
<div class="stat-grid">
    <div class="stat-card"><div class="stat-card-label">Owed to you (settled)</div><div class="stat-card-num">{{ Money::format($owed) }}</div></div>
    <div class="stat-card"><div class="stat-card-label">Paid out</div><div class="stat-card-num">{{ Money::format((int) $payouts->where('status', 'completed')->sum('amount_cents')) }}</div></div>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Settled Orders</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.2rem;">An order settles after the buyer's cash is handed in, the {{ config('picksell.return_window_days') }}-day return window has passed and no return is open. Your share is the item price minus commission and any refund.</div>
        </div>
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>Order</th><th>Settled</th><th>Your share</th><th>Payout</th></tr></thead>
            <tbody>
            @forelse($settled as $line)
                <tr>
                    <td>{{ $line->transaction->order->order_number ?? '—' }}</td>
                    <td>{{ $line->transaction->created_at->format('M d, Y') }}</td>
                    <td><strong>{{ Money::format(-$line->amount_cents) }}</strong></td>
                    <td>{{ $line->payoutItem ? '#' . $line->payoutItem->payout_id . ' · ' . ucfirst($line->payoutItem->payout->status) : 'Not yet' }}</td>
                </tr>
            @empty
                <tr><td colspan="4" style="text-align:center;color:#888;padding:2rem;">No settled orders yet.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($settled->hasPages())<div style="padding:1rem;">{{ $settled->links() }}</div>@endif
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Payouts</span></div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>#</th><th>Period</th><th>Amount</th><th>Status</th><th>Reference</th></tr></thead>
            <tbody>
            @forelse($payouts as $p)
                <tr>
                    <td>#{{ $p->id }}</td>
                    <td>{{ $p->period_start->format('M d') }} – {{ $p->period_end->format('M d, Y') }}</td>
                    <td>{{ Money::format($p->amount_cents) }}</td>
                    <td>{{ ucfirst($p->status) }}</td>
                    <td>{{ $p->reference ?? '—' }}</td>
                </tr>
            @empty
                <tr><td colspan="5" style="text-align:center;color:#888;padding:2rem;">No payouts yet.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
</div>
@endsection
