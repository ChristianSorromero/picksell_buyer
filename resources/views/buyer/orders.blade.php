@extends('buyer.layout')
@section('title', 'My Orders')

@section('styles')
<style>
    .status-tabs { display: flex; gap: 0; border-bottom: 2px solid #e8e2d8; margin-bottom: 1.5rem; overflow-x: auto; }
    .status-tab { padding: 0.7rem 1.2rem; font-size: 0.85rem; font-weight: 600; color: #888; cursor: pointer; white-space: nowrap; border-bottom: 2px solid transparent; margin-bottom: -2px; text-decoration: none; }
    .status-tab:hover { color: var(--coral); }
    .status-tab.active { color: var(--coral); border-bottom-color: var(--coral); }
    .order-card { background: #fff; border: 1px solid #e8e2d8; border-radius: 12px; margin-bottom: 1rem; overflow: hidden; }
    .order-card-header { padding: 0.8rem 1.2rem; background: #fafaf8; border-bottom: 1px solid #f0ebe0; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem; }
    .order-card-body { padding: 1rem 1.2rem; display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
    .order-track { display: flex; align-items: center; gap: 0; margin-top: 0.8rem; }
    .track-step { display: flex; flex-direction: column; align-items: center; flex: 1; }
    .track-dot { width: 12px; height: 12px; border-radius: 50%; background: #ddd; border: 2px solid #ddd; }
    .track-dot.done { background: var(--coral); border-color: var(--coral); }
    .track-line { flex: 1; height: 2px; background: #ddd; }
    .track-line.done { background: var(--coral); }
    .track-label { font-size: 0.68rem; color: #aaa; margin-top: 0.3rem; text-align: center; }
    .track-label.done { color: var(--coral); font-weight: 600; }
    .modal-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 200; align-items: center; justify-content: center; }
    .modal-overlay.open { display: flex; }
    .modal { background: #fff; border-radius: 14px; padding: 1.5rem; width: 100%; max-width: 440px; margin: 1rem; }
    .star-rating { display: flex; gap: 0.3rem; font-size: 1.8rem; cursor: pointer; }
    .star { color: #ddd; transition: color 0.15s; }
    .star.active { color: #f59e0b; }
</style>
@endsection

@section('content')
<h2 style="font-size:1.2rem;font-weight:800;margin-bottom:1rem;">My Orders</h2>

<div class="status-tabs">
    @foreach(['all'=>'All','pending'=>'To Ship','processing'=>'Preparing','shipped'=>'In Transit','completed'=>'Delivered','cancelled'=>'Cancelled'] as $val => $label)
    <a href="/buyer/orders?status={{ $val }}" class="status-tab {{ $status === $val ? 'active' : '' }}">{{ $label }}</a>
    @endforeach
</div>

@forelse($orders as $order)
<div class="order-card">
    <div class="order-card-header">
        <div>
            <span style="font-size:0.8rem;color:#888;">Order #</span>
            <strong>{{ $order->order_number }}</strong>
            <span style="margin-left:0.5rem;font-size:0.8rem;color:#aaa;">{{ $order->created_at->forDisplay()->format('M d, Y') }}</span>
        </div>
        <div style="display:flex;align-items:center;gap:0.8rem;">
            <span style="font-size:0.8rem;color:#888;">{{ $order->seller->business_name ?? $order->seller->full_name }}</span>
            @php
                $canonical = $order->canonical_status;
                $label = \App\Support\OrderStatus::EVENTS[$canonical][0] ?? $order->status;
            @endphp
            <span class="badge badge-{{ $order->status }}">{{ $label }}</span>
        </div>
    </div>
    @if($canonical === \App\Support\OrderStatus::DELIVERY_FAILED)
        <div class="alert alert-error" style="margin:0.6rem 1rem 0;">Delivery attempt failed: {{ \Illuminate\Support\Str::after($order->tracking_status, 'Delivery failed: ') }}. We'll try again — keep your phone nearby.</div>
    @elseif($canonical === \App\Support\OrderStatus::RETURNED)
        <div class="alert alert-error" style="margin:0.6rem 1rem 0;">We couldn't deliver this parcel, so it went back to the seller. You were not charged.</div>
    @endif
    <div class="order-card-body">
        @if($order->product && $order->product->image)
            <img src="{{ Storage::url($order->product->image) }}" style="width:60px;height:60px;object-fit:cover;border-radius:8px;">
        @else
            <div style="width:60px;height:60px;background:var(--bone);border-radius:8px;"></div>
        @endif
        <div style="flex:1;">
            <div style="font-weight:600;">{{ $order->product_name }}</div>
            <div style="font-size:0.8rem;color:#888;">Qty: {{ $order->quantity }}</div>
            <div style="font-size:0.95rem;font-weight:800;color:var(--coral);">{{ \App\Support\Money::format($order->totalCents()) }}</div>
            <div style="font-size:0.75rem;color:#888;">
                @switch($order->payment_status)
                    @case('unpaid') Pay in cash on delivery (incl. shipping) @break
                    @case('collected') @case('paid') Paid in cash @break
                    @case('partially_refunded') Paid · partly refunded @break
                    @case('refunded') Refunded @break
                @endswitch
            </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:0.4rem;align-items:flex-end;">
            @if($order->waybill_number)
            <div style="font-size:0.78rem;color:#888;">Waybill: <strong>{{ $order->waybill_number }}</strong></div>
            @endif
            @if($order->status === 'completed' && !$order->rating)
            <button class="btn btn-coral btn-sm" onclick="openFeedback({{ $order->id }})">Rate & Review</button>
            @endif
            @if($order->status === 'completed' && $order->rating)
            <div style="font-size:0.82rem;color:#888;">
                @for($i=1;$i<=5;$i++)<span style="color:{{ $i<=$order->rating ? '#f59e0b' : '#ddd' }};">★</span>@endfor
            </div>
            @endif
        </div>
    </div>

    {{-- Tracking Steps --}}
    @php
        $steps = ['pending'=>'To Ship','processing'=>'Preparing','shipped'=>'In Transit','completed'=>'Delivered'];
        $stepKeys = array_keys($steps);
        $currentIdx = array_search($order->status, $stepKeys);
    @endphp
    @if($order->status !== 'cancelled')
    <div style="padding:0 1.2rem 1rem;">
        <div class="order-track">
            @foreach($steps as $key => $label)
            @php $idx = array_search($key, $stepKeys); $done = $currentIdx !== false && $idx <= $currentIdx; @endphp
            @if(!$loop->first)<div class="track-line {{ $done ? 'done' : '' }}"></div>@endif
            <div class="track-step">
                <div class="track-dot {{ $done ? 'done' : '' }}"></div>
                <div class="track-label {{ $done ? 'done' : '' }}">{{ $label }}</div>
            </div>
            @endforeach
        </div>
    </div>
    @endif
</div>
@empty
<div style="text-align:center;padding:3rem;color:#aaa;">No orders found.</div>
@endforelse

@if($orders->hasPages())
<div class="dashboard-pagination" style="margin-top:1rem;">{{ $orders->withQueryString()->links() }}</div>
@endif

<!-- Feedback Modal -->
<div class="modal-overlay" id="feedbackModal">
    <div class="modal">
        <div style="font-size:1rem;font-weight:700;margin-bottom:1rem;">Rate Your Order</div>
        <form method="POST" id="feedbackForm">
            @csrf
            <div class="form-group">
                <label class="form-label">Rating</label>
                <div class="star-rating" id="starRating">
                    @for($i=1;$i<=5;$i++)
                    <span class="star" data-val="{{ $i }}" onclick="setRating({{ $i }})">★</span>
                    @endfor
                </div>
                <input type="hidden" name="rating" id="ratingInput" required>
            </div>
            <div class="form-group">
                <label class="form-label">Review (optional)</label>
                <textarea name="feedback" class="form-control" rows="3" placeholder="Share your experience..."></textarea>
            </div>
            <div style="display:flex;gap:0.8rem;justify-content:flex-end;margin-top:1rem;">
                <button type="button" class="btn btn-outline" onclick="document.getElementById('feedbackModal').classList.remove('open')">Cancel</button>
                <button type="submit" class="btn btn-coral">Submit</button>
            </div>
        </form>
    </div>
</div>
@endsection

@section('scripts')
<script>
function openFeedback(orderId) {
    document.getElementById('feedbackForm').action = '/buyer/orders/' + orderId + '/feedback';
    document.getElementById('ratingInput').value = '';
    document.querySelectorAll('.star').forEach(s => s.classList.remove('active'));
    document.getElementById('feedbackModal').classList.add('open');
}
function setRating(val) {
    document.getElementById('ratingInput').value = val;
    document.querySelectorAll('.star').forEach(s => {
        s.classList.toggle('active', parseInt(s.dataset.val) <= val);
    });
}
document.getElementById('feedbackModal').addEventListener('click', e => {
    if (e.target === document.getElementById('feedbackModal')) document.getElementById('feedbackModal').classList.remove('open');
});
</script>
@endsection
