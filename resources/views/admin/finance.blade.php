@extends('admin.layout')
@section('title', 'Finance')

@section('content')
@use('App\Support\Money')
@php $name = fn ($id) => $rec['users'][$id]->business_name ?? $rec['users'][$id]->full_name ?? "User #{$id}"; @endphp

<div class="alert alert-warning">Payouts are <strong>manual</strong>: transfer the money outside Picksell (bank or e-wallet), then record the reference here. Nothing is sent automatically.</div>

<div class="stat-grid">
    <div class="stat-card"><div class="stat-card-label">Cash at sorting center</div><div class="stat-card-num">{{ Money::format($rec['platform_cash']) }}</div></div>
    <div class="stat-card"><div class="stat-card-label">COD still with riders</div><div class="stat-card-num">{{ Money::format(array_sum($rec['rider_cash'])) }}</div></div>
    <div class="stat-card"><div class="stat-card-label">Owed to sellers</div><div class="stat-card-num">{{ Money::format(array_sum($rec['seller_owed'])) }}</div></div>
    <div class="stat-card"><div class="stat-card-label">Platform revenue (settled)</div><div class="stat-card-num">{{ Money::format($rec['platform_revenue']) }}</div></div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Settlement</span></div>
        <div class="card-body" style="font-size:0.85rem;">
            <p>{{ $rec['eligible_count'] }} order(s) ready to settle · {{ $rec['waiting_window'] }} paid order(s) still inside the {{ config('picksell.return_window_days') }}-day return window or with an open return.</p>
            <p style="color:#888;">Orders settle once the rider's cash is handed in, the return window has passed and no return is open. A daily job does this too.</p>
            <form method="POST" action="{{ route('admin.finance.settle') }}">@csrf<button class="btn btn-coral btn-sm">Settle eligible orders now</button></form>
            @unless($rec['rider_pay_configured'])
                <p style="color:#b45309;margin-top:0.8rem;">Rider pay policy is not configured (PICKSELL_RIDER_FEE_PER_DELIVERY), so no rider compensation is accrued.</p>
            @endunless
            <p style="color:#888;">Withholding (RR 16-2023): {{ $rec['withholding_enabled'] ? 'on' : 'off' }}{{ $rec['withholding_owed'] ? ' · ' . Money::format($rec['withholding_owed']) . ' withheld' : '' }}.</p>
        </div>
    </div>
    <div class="card">
        <div class="card-header"><span class="card-title">Create Payouts</span></div>
        <div class="card-body">
            <form method="POST" action="{{ route('admin.finance.generate') }}" style="display:flex;gap:0.5rem;align-items:flex-end;flex-wrap:wrap;">
                @csrf
                <div><label class="form-label">From</label><input type="date" name="period_start" class="form-control" value="{{ $periodStart->toDateString() }}"></div>
                <div><label class="form-label">To</label><input type="date" name="period_end" class="form-control" value="{{ $periodEnd->toDateString() }}"></div>
                <button class="btn btn-coral">Create pending payouts</button>
            </form>
            <p style="font-size:0.8rem;color:#888;margin-top:0.6rem;">Includes every settled, unpaid seller and rider share up to the end date. Each share can only be in one payout.</p>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title">Payouts</span></div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>#</th><th>Payee</th><th>Period</th><th>Amount</th><th>Status</th><th>Reference</th><th>Action</th></tr></thead>
            <tbody>
            @forelse($payouts as $p)
                <tr>
                    <td>#{{ $p->id }}</td>
                    <td>{{ $p->payee->business_name ?: $p->payee->full_name }}<div style="font-size:0.75rem;color:#888;">{{ $p->payee_role === 'courier' ? 'Rider' : 'Seller' }}</div></td>
                    <td>{{ $p->period_start->format('M d') }} – {{ $p->period_end->format('M d, Y') }}</td>
                    <td><strong>{{ Money::format($p->amount_cents) }}</strong></td>
                    <td><span class="badge {{ ['completed'=>'badge-approved','failed'=>'badge-suspended','cancelled'=>'badge-deactivated'][$p->status] ?? 'badge-pending' }}">{{ ucfirst($p->status) }}</span></td>
                    <td>{{ $p->reference ?? $p->failure_reason ?? '—' }}</td>
                    <td>
                        <form method="POST" action="{{ route('admin.finance.payout', $p) }}" style="display:flex;gap:0.3rem;flex-wrap:wrap;align-items:center;">
                            @csrf @method('PATCH')
                            @if($p->status === 'pending')
                                <button name="action" value="approve" class="btn btn-success btn-sm">Approve</button>
                            @elseif($p->status === 'approved')
                                <button name="action" value="processing" class="btn btn-outline btn-sm">Transfer started</button>
                            @endif
                            @if(in_array($p->status, ['approved', 'processing'], true))
                                <input type="text" name="reference" class="form-control" placeholder="Transfer reference" style="width:150px;">
                                <button name="action" value="complete" class="btn btn-coral btn-sm">Mark paid</button>
                                <input type="text" name="reason" class="form-control" placeholder="Failure reason" style="width:130px;">
                                <button name="action" value="fail" class="btn btn-outline btn-sm">Failed</button>
                            @endif
                            @if($p->status === 'pending')
                                <input type="text" name="reason" class="form-control" placeholder="Cancel reason" style="width:130px;">
                                <button name="action" value="cancel" class="btn btn-outline btn-sm">Cancel</button>
                            @endif
                        </form>
                    </td>
                </tr>
            @empty
                <tr><td colspan="7" style="text-align:center;color:#888;padding:2rem;">No payouts yet.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($payouts->hasPages())<div style="padding:1rem;">{{ $payouts->links() }}</div>@endif
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Balances</span></div>
        <div style="overflow-x:auto;">
            <table>
                <thead><tr><th>Who</th><th>Owed / holding</th><th>In open payouts</th></tr></thead>
                <tbody>
                @foreach($rec['seller_owed'] as $id => $cents)
                    <tr><td>{{ $name($id) }} <span style="color:#888;">(seller)</span></td><td>{{ Money::format($cents) }} owed</td><td>{{ Money::format($rec['in_payouts'][$id] ?? 0) }}</td></tr>
                @endforeach
                @foreach($rec['rider_owed'] as $id => $cents)
                    <tr><td>{{ $name($id) }} <span style="color:#888;">(rider)</span></td><td>{{ Money::format($cents) }} owed</td><td>{{ Money::format($rec['in_payouts'][$id] ?? 0) }}</td></tr>
                @endforeach
                @foreach($rec['rider_cash'] as $id => $cents)
                    <tr><td>{{ $name($id) }} <span style="color:#888;">(rider cash)</span></td><td>{{ Money::format($cents) }} to hand in</td><td>—</td></tr>
                @endforeach
                @if(!$rec['seller_owed'] && !$rec['rider_owed'] && !$rec['rider_cash'])
                    <tr><td colspan="3" style="text-align:center;color:#888;">Nothing outstanding.</td></tr>
                @endif
                </tbody>
            </table>
        </div>
    </div>
    <div class="card">
        <div class="card-header"><span class="card-title">Reconciliation Checks</span></div>
        <div class="card-body" style="font-size:0.85rem;">
            <p>COD collected, not handed in: <strong>{{ $rec['collected_orders']->count() }}</strong> order(s), {{ Money::format($rec['collected_cents']) }}
                @if($oldest = $rec['collected_orders']->first()) · oldest {{ $oldest->cod_collected_at->diffForHumans() }}@endif</p>
            <p>Approved refunds not yet handed to buyers: <strong>{{ $rec['refunds_pending']->count() }}</strong></p>
            <p>Delivered with no COD collection recorded (older orders): <strong>{{ count($rec['discrepancies']['delivered_without_collection']) }}</strong>
                @if($rec['discrepancies']['delivered_without_collection'])<br><span style="color:#888;">{{ implode(', ', array_slice($rec['discrepancies']['delivered_without_collection'], 0, 10)) }}</span>@endif</p>
            <p>Settled orders with unallocated funds: <strong style="color:{{ $rec['discrepancies']['settled_with_open_funds'] ? '#dc2626' : 'inherit' }}">{{ count($rec['discrepancies']['settled_with_open_funds']) }}</strong></p>
            <p>Ledger balance check: <strong style="color:{{ $rec['discrepancies']['ledger_out_of_balance'] ? '#dc2626' : '#16a34a' }}">{{ $rec['discrepancies']['ledger_out_of_balance'] ? 'OUT OF BALANCE by ' . Money::format($rec['discrepancies']['ledger_out_of_balance']) : 'balanced' }}</strong></p>
        </div>
    </div>
</div>
@endsection
