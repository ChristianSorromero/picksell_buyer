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
            <p style="margin-top:0.8rem;"><strong>Rider pay:</strong>
                @if($rec['rider_pay_status'] === 'unconfigured')
                    <span style="color:#b45309;">not configured — no rider compensation is accrued.</span>
                @elseif($rec['rider_pay_status'] === 'proposed')
                    <span style="color:#b45309;">proposed, not active ({{ Money::format($rec['rider_pay_rates']['base_per_stop']) }} per stop, {{ Money::format($rec['rider_pay_rates']['additional_parcel']) }} per extra parcel). Nothing accrues until it is approved.</span>
                @else
                    active: {{ Money::format($rec['rider_pay_rates']['base_per_stop']) }} per stop, {{ Money::format($rec['rider_pay_rates']['additional_parcel']) }} per extra parcel, accrued when the cash is handed in.
                @endif
            </p>
            <p style="color:#888;">Withholding (RR 16-2023): {{ $rec['withholding_enabled'] ? 'on' : 'off — not legally validated or enabled' }}{{ $rec['withholding_owed'] ? ' · ' . Money::format($rec['withholding_owed']) . ' withheld' : '' }}.</p>
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
                    <td>{{ $p->reference ?? $p->failure_reason ?? '—' }}@if($p->disbursed_on)<div style="font-size:0.75rem;color:#888;">Sent {{ $p->disbursed_on->format('M d, Y') }}</div>@endif</td>
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
                                <input type="date" name="disbursed_on" class="form-control" max="{{ now()->toDateString() }}" title="Date the money was sent" style="width:150px;">
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
            <p>Returns waiting for admin: <strong>{{ $rec['returns_awaiting_admin'] }}</strong> · Responsibility undetermined: <strong>{{ $rec['undetermined_liability'] }}</strong> · Payouts in progress: <strong>{{ $rec['payouts_pending'] }}</strong></p>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Orders Delivered Before COD Tracking</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.2rem;">These have no recorded cash collection. Record a historical payment only with trustworthy evidence (courier remittance sheet, deposit slip, signed hand-in log). Otherwise mark it unverifiable — it then stays out of settlement and refunds.</div>
        </div>
    </div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Order</th><th>Delivered</th><th>Total</th><th>Status</th><th>Record verified payment</th><th>No evidence</th></tr></thead>
        <tbody>
        @forelse($rec['legacy_orders'] as $o)
            <tr>
                <td>{{ $o->order_number }}@if($o->returnRequest)<div style="font-size:0.75rem;color:#b45309;">Return #{{ $o->returnRequest->id }} ({{ \App\Models\ReturnRequest::STAGE_LABELS[$o->returnRequest->status] ?? $o->returnRequest->status }})</div>@endif</td>
                <td>{{ $o->delivered_at?->format('M d, Y') ?? '—' }}</td>
                <td>{{ Money::format($o->totalCents()) }}</td>
                <td>{{ $o->payment_review === 'unverifiable' ? 'Unverifiable: ' . $o->payment_review_note : 'Not reviewed' }}</td>
                <td>
                    <form method="POST" action="{{ route('admin.finance.backfill', $o) }}" style="display:flex;flex-direction:column;gap:0.3rem;min-width:220px;">
                        @csrf
                        <input type="number" name="amount" step="0.01" min="0" class="form-control" placeholder="Amount per evidence" required>
                        <input type="text" name="evidence" class="form-control" placeholder="Evidence reference" required>
                        <input type="text" name="reason" class="form-control" placeholder="Why this is trustworthy" required>
                        <input type="date" name="collected_on" class="form-control" max="{{ now()->toDateString() }}" title="Collection date, only if the evidence shows it">
                        <button class="btn btn-coral btn-sm" onclick="return confirm('Record this historical payment? It must match verified evidence.')">Record historical payment</button>
                    </form>
                </td>
                <td>
                    @if($o->payment_review !== 'unverifiable')
                    <form method="POST" action="{{ route('admin.finance.unverifiable', $o) }}" style="display:flex;flex-direction:column;gap:0.3rem;">
                        @csrf
                        <input type="text" name="note" class="form-control" placeholder="What was checked" required>
                        <button class="btn btn-outline btn-sm">Mark unverifiable</button>
                    </form>
                    @endif
                </td>
            </tr>
        @empty
            <tr><td colspan="6" style="text-align:center;color:#888;padding:1.5rem;">No legacy orders need review.</td></tr>
        @endforelse
        </tbody>
    </table></div>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Seller Tax Details (RR 16-2023 preparation)</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.2rem;">Recorded for a future, professionally reviewed withholding setup. Withholding is {{ $rec['withholding_enabled'] ? 'ON' : 'OFF' }} and nothing here changes payouts.</div>
        </div>
    </div>
    <div style="overflow-x:auto;"><table>
        <thead><tr><th>Seller</th><th>Recorded</th><th>Update</th></tr></thead>
        <tbody>
        @forelse($sellers as $s)
            @php $tp = $taxProfiles[$s->id] ?? null; @endphp
            <tr>
                <td>{{ $s->business_name ?: $s->full_name }}</td>
                <td style="font-size:0.8rem;">
                    @if($tp)
                        TIN {{ $tp->tin ?? '—' }} · COR {{ $tp->bir_cor_number ?? '—' }}<br>
                        Sworn declaration: {{ $tp->sworn_declaration_year ?? '—' }}{{ $tp->sworn_declaration_received_on ? ' (received ' . $tp->sworn_declaration_received_on->format('M d, Y') . ')' : '' }}<br>
                        {{ $tp->verified_at ? 'Verified by ' . ($tp->verifiedBy->full_name ?? 'admin') . ' on ' . $tp->verified_at->format('M d, Y') : 'Not verified' }}
                    @else
                        <span style="color:#888;">Nothing recorded</span>
                    @endif
                </td>
                <td>
                    <form method="POST" action="{{ route('admin.finance.tax', $s) }}" style="display:flex;gap:0.3rem;flex-wrap:wrap;align-items:center;">
                        @csrf
                        <input type="text" name="tin" class="form-control" placeholder="TIN" value="{{ $tp->tin ?? '' }}" style="width:150px;">
                        <input type="text" name="bir_cor_number" class="form-control" placeholder="COR (Form 2303) no." value="{{ $tp->bir_cor_number ?? '' }}" style="width:160px;">
                        <input type="number" name="sworn_declaration_year" class="form-control" placeholder="SD year" value="{{ $tp->sworn_declaration_year ?? '' }}" style="width:100px;">
                        <input type="date" name="sworn_declaration_received_on" class="form-control" value="{{ $tp?->sworn_declaration_received_on?->toDateString() }}" max="{{ now()->toDateString() }}" style="width:150px;">
                        <label style="font-size:0.78rem;"><input type="checkbox" name="verified" value="1" @checked($tp?->verified_at)> Documents checked</label>
                        <button class="btn btn-outline btn-sm">Save</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="3" style="text-align:center;color:#888;padding:1.5rem;">No approved sellers.</td></tr>
        @endforelse
        </tbody>
    </table></div>
</div>
@endsection
