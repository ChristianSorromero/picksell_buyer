@extends('seller.layout')
@section('title', 'Return #' . $r->id)

@section('content')
@use('App\Models\ReturnRequest', 'RR')
@use('App\Support\Money')
<div style="margin-bottom:1rem;"><a href="{{ route('seller.returns') }}" class="btn btn-outline btn-sm">← Back to Returns</a></div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Return #{{ $r->id }} · {{ $r->order->order_number }}</span></div>
        <div class="card-body" style="font-size:0.88rem;">
            <p><strong>Stage:</strong> {{ RR::STAGE_LABELS[$r->status] }}</p>
            <p><strong>Item:</strong> {{ $r->quantity }} × {{ $r->order->product_name }}{{ $r->order->variation_label ? ' (' . $r->order->variation_label . ')' : '' }}</p>
            <p><strong>Reason:</strong> {{ $r->reason }}</p>
            @if($r->details)<p style="white-space:pre-line;"><strong>Buyer says:</strong> {{ $r->details }}</p>@endif
            <p><strong>Order total paid:</strong> {{ Money::format($maxRefund) }} (Cash on Delivery)</p>
            @if($r->resolution_type)
                <p><strong>{{ $r->status === RR::PROPOSED ? 'Your proposal' : 'Resolution' }}:</strong> {{ RR::RESOLUTIONS[$r->resolution_type][0] }} — {{ Money::format($r->resolutionCents()) }}</p>
            @endif
            <p style="color:#888;">Talk to the buyer in <a href="/seller/chat" style="color:var(--coral);">Messages</a> before proposing.</p>
        </div>
    </div>

    <div>
        @if($r->status === RR::WITH_SELLER)
        <div class="card">
            <div class="card-header"><span class="card-title">Propose a Resolution</span></div>
            <div class="card-body">
                <form method="POST" action="{{ route('seller.returns.propose', $r) }}">
                    @csrf
                    <div class="form-group">
                        <label class="form-label">Resolution</label>
                        <select name="resolution_type" class="form-control" required>
                            @foreach(RR::RESOLUTIONS as $code => [$name])<option value="{{ $code }}">{{ $name }}</option>@endforeach
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Refund amount (₱), up to {{ Money::format($maxRefund) }} — not needed for full refund or replacement</label>
                        <input type="number" name="resolution_amount" step="0.01" min="0" class="form-control">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Message to the buyer</label>
                        <textarea name="note" class="form-control" rows="2"></textarea>
                    </div>
                    <button class="btn btn-coral">Send proposal</button>
                </form>
                <form method="POST" action="{{ route('seller.returns.decline', $r) }}" style="margin-top:1rem;">
                    @csrf
                    <label class="form-label">Or decline — Picksell will make the final decision</label>
                    <textarea name="note" class="form-control" rows="2" required placeholder="Why you don't accept this return"></textarea>
                    <button class="btn btn-outline" style="margin-top:0.5rem;">Decline</button>
                </form>
            </div>
        </div>
        @endif

        @if($r->needsItemReceipt() && ($r->item_collected_at || $r->resolution_type === 'replacement'))
        <div class="card">
            <div class="card-header"><span class="card-title">Returned Item</span></div>
            <div class="card-body">
                <p style="font-size:0.85rem;color:#888;">Confirm once the item is physically with you and inspected. Only restock it if it can be sold again.</p>
                <form method="POST" action="{{ route('seller.returns.received', $r) }}" style="display:flex;gap:0.5rem;">
                    @csrf
                    <button name="restock" value="1" class="btn btn-success">Received — put back in stock</button>
                    <button name="restock" value="0" class="btn btn-outline">Received — don't restock</button>
                </form>
            </div>
        </div>
        @elseif($r->needsItemReceipt())
            <div class="card"><div class="card-body" style="font-size:0.85rem;color:#888;">The rider will collect the item from the buyer when handing over the refund.</div></div>
        @endif

        @if($r->status === RR::RESOLVED && $r->resolution_type === 'replacement' && !$r->replacement_sent_at)
        <div class="card">
            <div class="card-header"><span class="card-title">Replacement</span></div>
            <div class="card-body">
                <form method="POST" action="{{ route('seller.returns.replacement', $r) }}">
                    @csrf
                    <input type="text" name="note" class="form-control" placeholder="Waybill or note (optional)">
                    <button class="btn btn-coral" style="margin-top:0.5rem;">Replacement sent</button>
                </form>
            </div>
        </div>
        @endif

        <div class="card">
            <div class="card-header"><span class="card-title">History</span></div>
            <div class="card-body">
                @foreach($r->auditLogs as $log)
                    <div style="font-size:0.8rem;padding:0.3rem 0;border-bottom:1px solid #f0ebe0;">
                        <strong>{{ str_replace('_', ' ', $log->action) }}</strong> · {{ $log->created_at->format('M d, h:i A') }} · {{ $log->actor_role ?? '—' }}
                        @if($log->note)<div style="color:#666;">{{ $log->note }}</div>@endif
                    </div>
                @endforeach
            </div>
        </div>
    </div>
</div>
@endsection
