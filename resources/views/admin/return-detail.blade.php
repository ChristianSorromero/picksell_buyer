@extends('admin.layout')
@section('title', 'Return #' . $r->id)

@section('content')
@use('App\Models\ReturnRequest', 'RR')
@use('App\Support\Money')
@php
    $order = $r->order;
    $label = 'font-weight:600;color:#888;padding:0.35rem 0.8rem 0.35rem 0;width:150px;';
@endphp
<div style="margin-bottom:1rem;"><a href="{{ route('admin.returns') }}" class="btn btn-outline btn-sm">← Back to Returns</a></div>

<div class="grid-2">
    <div>
        <div class="card">
            <div class="card-header"><span class="card-title">Return #{{ $r->id }}</span><span class="badge badge-pending">{{ RR::STAGE_LABELS[$r->status] ?? $r->status }}</span></div>
            <div class="card-body">
                <table style="font-size:0.88rem;">
                    <tr><td style="{{ $label }}">Buyer</td><td>{{ $r->buyer->full_name ?? '—' }}</td></tr>
                    <tr><td style="{{ $label }}">Reason</td><td>{{ $r->reason }}</td></tr>
                    <tr><td style="{{ $label }}">Quantity</td><td>{{ $r->quantity }} of {{ $order->quantity }}</td></tr>
                    <tr><td style="{{ $label }}">Buyer asks for</td><td>{{ Money::format(Money::cents($r->refund_amount)) }} (items)</td></tr>
                    <tr><td style="{{ $label }}">Max refundable</td><td>{{ Money::format($maxRefund) }} (order total)</td></tr>
                    @if($r->resolution_type)
                    <tr><td style="{{ $label }}">{{ $r->status === RR::PROPOSED ? 'Seller proposes' : 'Resolution' }}</td><td>{{ RR::RESOLUTIONS[$r->resolution_type][0] }} — {{ Money::format($r->resolutionCents()) }}</td></tr>
                    @endif
                    <tr><td style="{{ $label }}">Requested</td><td>{{ $r->created_at->format('M d, Y h:i A') }}</td></tr>
                </table>
                @if($r->details)
                    <div style="margin-top:0.8rem;background:#fafaf8;border:1px solid #f0ebe0;border-radius:8px;padding:0.8rem;font-size:0.86rem;white-space:pre-line;">{{ $r->details }}</div>
                @endif
                @if($r->evidence_paths)
                    <div style="margin-top:0.8rem;display:flex;gap:0.4rem;flex-wrap:wrap;">
                        @foreach($r->evidence_paths as $i => $path)
                            <a href="{{ route('admin.returns.evidence', [$r, $i]) }}" target="_blank" class="btn btn-outline btn-sm">Photo {{ $i + 1 }}</a>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>

        <div class="card">
            <div class="card-header"><span class="card-title">Order & Payment</span></div>
            <div class="card-body">
                <table style="font-size:0.88rem;">
                    <tr><td style="{{ $label }}">Order</td><td>{{ $order->order_number }} · {{ $order->product_name }}{{ $order->variation_label ? ' (' . $order->variation_label . ')' : '' }}</td></tr>
                    <tr><td style="{{ $label }}">Seller</td><td>{{ $order->seller->business_name ?? $order->seller->full_name ?? '—' }}</td></tr>
                    <tr><td style="{{ $label }}">Order total</td><td>{{ Money::format($order->totalCents()) }}</td></tr>
                    <tr><td style="{{ $label }}">Payment</td><td>{{ ucfirst(str_replace('_', ' ', $order->payment_status)) }} (Cash on Delivery){{ $order->paid_at ? ' · handed in ' . $order->paid_at->format('M d, Y') : '' }}</td></tr>
                    <tr><td style="{{ $label }}">Delivered</td><td>{{ $order->delivered_at?->format('M d, Y h:i A') ?? '—' }} by {{ $order->courier->full_name ?? '—' }}</td></tr>
                </table>
                <div style="margin-top:0.8rem;font-size:0.82rem;font-weight:600;">Delivery history</div>
                <ul style="font-size:0.8rem;color:#666;padding-left:1.1rem;margin:0.3rem 0 0;">
                    @foreach($order->events as $event)
                        <li>{{ $event->occurred_at->format('M d, h:i A') }} — {{ $event->title }}</li>
                    @endforeach
                </ul>
            </div>
        </div>
    </div>

    <div>
        @if(in_array($r->status, [RR::REQUESTED, RR::INFO_REQUESTED], true))
        <div class="card">
            <div class="card-header"><span class="card-title">Admin Review</span></div>
            <div class="card-body">
                @if($r->status === RR::REQUESTED)
                <form method="POST" action="{{ route('admin.returns.approve', $r) }}" class="form-group">
                    @csrf
                    <label class="form-label">Approve and send to the seller</label>
                    @php $presumed = config("picksell.returns.presumed_liability.{$r->reason}", 'undetermined'); @endphp
                    <select name="liable_party" class="form-control" style="margin-bottom:0.4rem;">
                        @foreach(RR::LIABLE_PARTIES as $code => $name)
                            <option value="{{ $code }}" @selected($code === $presumed)>Responsible: {{ $name }}{{ $code === $presumed ? ' (presumed)' : '' }}</option>
                        @endforeach
                    </select>
                    <textarea name="note" class="form-control" rows="2" placeholder="Basis for this determination (evidence reviewed)"></textarea>
                    <button class="btn btn-coral" style="margin-top:0.5rem;">Approve for seller resolution</button>
                </form>
                <form method="POST" action="{{ route('admin.returns.info', $r) }}" class="form-group">
                    @csrf
                    <label class="form-label">Ask the buyer for more information</label>
                    <textarea name="question" class="form-control" rows="2" required placeholder="e.g. Please send a photo of the serial number."></textarea>
                    <button class="btn btn-outline" style="margin-top:0.5rem;">Request information</button>
                </form>
                @else
                    <p style="font-size:0.85rem;color:#888;">Waiting for the buyer to answer: “{{ $r->info_request }}”</p>
                @endif
                <form method="POST" action="{{ route('admin.returns.reject', $r) }}" class="form-group">
                    @csrf
                    <label class="form-label">Reject</label>
                    <textarea name="reason" class="form-control" rows="2" required placeholder="Reason shown to the buyer"></textarea>
                    <button class="btn btn-danger" style="margin-top:0.5rem;">Reject request</button>
                </form>
            </div>
        </div>
        @endif

        @if($r->status === RR::ESCALATED)
        <div class="card">
            <div class="card-header"><span class="card-title">Final Decision</span></div>
            <div class="card-body">
                @if($r->seller_note)<p style="font-size:0.85rem;"><strong>Seller:</strong> {{ $r->seller_note }}</p>@endif
                <form method="POST" action="{{ route('admin.returns.decide', $r) }}">
                    @csrf
                    <div class="form-group">
                        <label class="form-label">Outcome</label>
                        <select name="resolution_type" class="form-control" required>
                            @foreach(RR::RESOLUTIONS as $code => [$name])<option value="{{ $code }}">{{ $name }}</option>@endforeach
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Refund amount (₱) — up to {{ Money::format($maxRefund) }}; ignored for full refund or replacement</label>
                        <input type="number" name="resolution_amount" step="0.01" min="0" class="form-control">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Responsible party</label>
                        <select name="liable_party" class="form-control">
                            <option value="">Keep current ({{ RR::LIABLE_PARTIES[$r->liable_party] ?? 'not set' }})</option>
                            @foreach(RR::LIABLE_PARTIES as $code => $name)<option value="{{ $code }}">{{ $name }}</option>@endforeach
                        </select>
                    </div>
                    @if($r->inspection_passed === false)<p style="font-size:0.82rem;color:#b45309;">The seller reported a failed inspection: {{ $r->inspection_note }}</p>@endif
                    <div class="form-group">
                        <label class="form-label">Decision note</label>
                        <textarea name="note" class="form-control" rows="2" required></textarea>
                    </div>
                    <button class="btn btn-coral">Record final decision</button>
                </form>
                <form method="POST" action="{{ route('admin.returns.reject', $r) }}" style="margin-top:0.8rem;">
                    @csrf
                    <input type="text" name="reason" class="form-control" required placeholder="Reason for rejecting">
                    <button class="btn btn-danger" style="margin-top:0.5rem;">Reject</button>
                </form>
            </div>
        </div>
        @endif

        @if($r->status !== RR::REQUESTED && $r->status !== RR::INFO_REQUESTED)
        <div class="card">
            <div class="card-header"><span class="card-title">Responsibility & Refund Rules</span></div>
            <div class="card-body" style="font-size:0.85rem;">
                <p style="margin-top:0;">Responsible: <strong>{{ RR::LIABLE_PARTIES[$r->liable_party] ?? 'Not set' }}</strong> · Refund funded by: <strong>{{ $r->refund_funded_by ? ucfirst($r->refund_funded_by) : 'not decided' }}</strong>
                    @if($r->liability_note)<br><span style="color:#888;">{{ $r->liability_note }}</span>@endif</p>
                <p style="color:#888;">The rider who hands over refund cash only holds it; they are never charged for the refund.</p>
                @if($r->refund_timing)<p>Refund timing: <strong>{{ RR::TIMING_LABELS[$r->refund_timing] }}</strong>{{ $r->expedited_reason ? ' — ' . $r->expedited_reason : '' }}</p>@endif
                @if($r->status !== RR::REJECTED && !$order->settled_at)
                <form method="POST" action="{{ route('admin.returns.liability', $r) }}" style="display:flex;gap:0.4rem;flex-wrap:wrap;">
                    @csrf
                    <select name="liable_party" class="form-control" style="max-width:280px;">
                        @foreach(RR::LIABLE_PARTIES as $code => $name)<option value="{{ $code }}" @selected($code === $r->liable_party)>{{ $name }}</option>@endforeach
                    </select>
                    <input type="text" name="note" class="form-control" placeholder="Evidence / basis (required)" required style="max-width:280px;">
                    <button class="btn btn-outline btn-sm">Update responsibility</button>
                </form>
                @endif
                @if($r->status === RR::RESOLVED && $r->refund_timing === 'after_inspection' && !$r->item_collected_at && !$r->refund_released_at)
                <form method="POST" action="{{ route('admin.returns.expedite', $r) }}" style="margin-top:0.8rem;">
                    @csrf
                    <label class="form-label">Exception: refund on pickup (verified damaged, wrong or missing item)</label>
                    <input type="text" name="reason" class="form-control" placeholder="Why the evidence justifies skipping inspection" required>
                    <button class="btn btn-outline btn-sm" style="margin-top:0.4rem;">Expedite refund</button>
                </form>
                @endif
            </div>
        </div>
        @endif

        @if($r->status === RR::RESOLVED)
        <div class="card">
            <div class="card-header"><span class="card-title">Fulfilment</span></div>
            <div class="card-body" style="font-size:0.85rem;">
                <div>Refund: {{ $r->resolutionCents() > 0 ? ($r->refunded_at ? 'handed over ' . $r->refunded_at->format('M d') : ($r->refund_released_at ? 'cash with ' . ($r->refundCourier->full_name ?? 'rider') : ($r->refundBlocker() ?? 'ready for the sorting center to release cash'))) : 'none' }}</div>
                @if($r->requires_item_return)<div>Item: {{ $r->item_received_at ? 'received by seller' . ($r->inspection_passed === false ? ' — FAILED inspection' : '') . ($r->restocked ? ' (restocked)' : '') : ($r->item_collected_at ? 'collected from buyer' : ($r->pickupCourier ? 'pickup assigned to ' . $r->pickupCourier->full_name : 'waiting for pickup')) }}</div>@endif
                @if($r->inspection_note)<div style="color:#888;">Inspection: {{ $r->inspection_note }}</div>@endif
                @if($r->resolution_type === 'replacement')<div>Replacement: {{ $r->replacement_sent_at ? 'sent' : 'not sent yet' }}</div>@endif
            </div>
        </div>
        @endif

        <div class="card">
            <div class="card-header"><span class="card-title">Audit Trail</span></div>
            <div class="card-body">
                @foreach($r->auditLogs as $log)
                    <div style="font-size:0.8rem;padding:0.35rem 0;border-bottom:1px solid #f0ebe0;">
                        <strong>{{ str_replace('_', ' ', $log->action) }}</strong>
                        @if($log->amount_cents !== null) · {{ Money::format($log->amount_cents) }}@endif
                        <div style="color:#888;">{{ $log->created_at->format('M d, Y h:i A') }} · {{ $log->actor->full_name ?? 'System' }} ({{ $log->actor_role ?? '—' }})</div>
                        @if($log->note)<div>{{ $log->note }}</div>@endif
                    </div>
                @endforeach
            </div>
        </div>
    </div>
</div>
@endsection
