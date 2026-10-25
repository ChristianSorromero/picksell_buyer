@extends('buyer.layout')
@section('title', 'My Cart')

@section('content')
<h2 style="font-size:1.2rem;font-weight:800;margin-bottom:1.2rem;">My Cart ({{ $items->count() }} item{{ $items->count() !== 1 ? 's' : '' }})</h2>

@if($items->isEmpty())
<div style="text-align:center;padding:4rem 1rem;color:#aaa;">
    <svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" fill="currentColor" viewBox="0 0 24 24" style="margin-bottom:1rem;opacity:0.3;"><path d="M7 18c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zM5.2 5H2V3H0v2h2l3.6 7.59L4.25 15A2 2 0 0 0 6 18h14v-2H6.42a.25.25 0 0 1-.25-.25l.03-.12L7.1 14h9.45c.75 0 1.41-.41 1.75-1.03L21.7 6.5A1 1 0 0 0 20.83 5H5.2z"/></svg>
    <div style="font-size:1rem;font-weight:600;margin-bottom:0.5rem;">Your cart is empty</div>
    <a href="/buyer/shop" class="btn btn-coral" style="margin-top:0.5rem;">Start Shopping</a>
</div>
@else
<form method="POST" action="/buyer/cart/checkout" id="checkoutForm">
    @csrf
    <div style="display:grid;grid-template-columns:1fr 340px;gap:1.5rem;align-items:start;">
        <div>
            <div class="card">
                <div class="card-header">
                    <label style="display:flex;align-items:center;gap:0.5rem;font-size:0.85rem;cursor:pointer;">
                        <input type="checkbox" id="selectAll" onchange="toggleAll(this)"> Select All
                    </label>
                </div>
                <div style="overflow-x:auto;">
                    <table>
                        <thead><tr><th></th><th>Product</th><th>Variation</th><th>Price</th><th>Qty</th><th>Subtotal</th><th></th></tr></thead>
                        <tbody>
                        @foreach($items as $item)
                        <tr>
                            <td><input type="checkbox" name="item_ids[]" value="{{ $item->id }}" class="item-check" data-seller="{{ $item->product->seller_id }}" onchange="updateSummary()"></td>
                            <td>
                                <div style="display:flex;align-items:center;gap:0.6rem;">
                                    @if($item->product->image)
                                        <img src="{{ Storage::url($item->product->image) }}" style="width:44px;height:44px;object-fit:cover;border-radius:6px;">
                                    @else
                                        <div style="width:44px;height:44px;background:var(--bone);border-radius:6px;"></div>
                                    @endif
                                    <div>
                                        <div style="font-weight:600;font-size:0.88rem;">{{ $item->product->name }}</div>
                                        <div style="font-size:0.75rem;color:#aaa;">{{ $item->product->seller->business_name ?? $item->product->seller->full_name }}</div>
                                    </div>
                                </div>
                            </td>
                            <td style="font-size:0.82rem;color:#666;">{{ $item->variation ? $item->variation->type.': '.$item->variation->value : '—' }}</td>
                            <td style="font-weight:600;color:var(--coral);">₱{{ number_format($item->product->effective_price, 2) }}</td>
                            <td>
                                <div style="display:flex;align-items:center;gap:0.3rem;">
                                    <input type="number"
                                           name="quantity"
                                           value="{{ $item->quantity }}"
                                           min="1"
                                           max="{{ min($item->product->stock, $maxPerItem) }}"
                                           data-item-id="{{ $item->id }}"
                                           class="qty-input"
                                           style="width:55px;padding:0.3rem;border:1.5px solid #ddd6c8;border-radius:6px;text-align:center;font-size:0.85rem;">
                                </div>
                            </td>
                            <td style="font-weight:700;" data-subtotal="{{ $item->product->effective_price * $item->quantity }}">₱{{ number_format($item->product->effective_price * $item->quantity, 2) }}</td>
                            <td>
                                <button type="button" class="btn btn-sm remove-item-btn" data-item-id="{{ $item->id }}" style="background:none;border:none;color:#dc2626;cursor:pointer;" title="Remove">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>
                                </button>
                            </td>
                        </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div>
            <div class="card">
                <div class="card-header"><span class="card-title">Order Summary</span></div>
                <div class="card-body">
                    <div class="form-group">
                        <label class="form-label">Voucher Code</label>
                        <input type="text" name="voucher_code" class="form-control" placeholder="Enter voucher code">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Deliver To</label>
                        @if($shipTo)
                            <div style="font-size:0.85rem;">{{ $shipTo['recipient_name'] }} · {{ $shipTo['phone'] }}</div>
                            <div style="font-size:0.8rem;color:#888;">{{ $shipTo['full_address'] }}</div>
                        @else
                            <small style="display:block;color:#b45309;">Add your address in <a href="/buyer/account">My Account</a> before placing an order.</small>
                        @endif
                    </div>
                    <div class="form-group">
                        <label class="form-label">Shipping Option *</label>
                        <select name="shipping_option" id="shippingOption" class="form-control" onchange="updateSummary()" required>
                            @foreach($shippingOptions as $option)
                                <option value="{{ $option['code'] }}" data-fee="{{ $option['fee'] }}">{{ $option['name'] }} — ₱{{ number_format($option['fee'], 2) }} per store ({{ $option['min_days'] }}–{{ $option['max_days'] }} days)</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Payment Method *</label>
                        <select name="payment_method" class="form-control" required>
                            @foreach($paymentMethods as $method)
                                <option value="{{ $method['code'] }}" @disabled(!$method['available'])>{{ $method['name'] }}{{ $method['available'] ? '' : ' (coming soon)' }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">PickSell Logistics</label>
                        <select name="logistics_id" class="form-control">
                            <option value="">Automatic (by delivery area)</option>
                            @foreach($logisticsProviders as $provider)
                                <option value="{{ $provider->id }}">{{ $provider->business_name ?: $provider->full_name }}</option>
                            @endforeach
                        </select>
                        @if($logisticsProviders->isEmpty())
                            <small style="display:block;color:#b45309;margin-top:.35rem;">No approved logistics providers are available yet.</small>
                        @endif
                    </div>
                    <hr style="border:none;border-top:1px solid #f0ebe0;margin:1rem 0;">
                    <div style="display:flex;justify-content:space-between;font-size:0.88rem;margin-bottom:0.5rem;">
                        <span style="color:#888;">Selected Items</span>
                        <span id="selectedCount">0</span>
                    </div>
                    <div style="display:flex;justify-content:space-between;font-size:0.88rem;margin-bottom:0.5rem;">
                        <span style="color:#888;">Shipping</span>
                        <span id="shippingAmount">₱0.00</span>
                    </div>
                    <div style="display:flex;justify-content:space-between;font-size:1rem;font-weight:800;margin-bottom:0.3rem;">
                        <span>Total</span>
                        <span style="color:var(--coral);" id="totalAmount">₱0.00</span>
                    </div>
                    <div style="font-size:0.75rem;color:#888;margin-bottom:1rem;">Vouchers are applied when you place the order.</div>
                    <button type="submit" class="btn btn-coral" style="width:100%;justify-content:center;" id="placeOrderBtn" disabled data-can-order="{{ $shipTo ? '1' : '0' }}">
                        Place Order
                    </button>
                </div>
            </div>
        </div>
    </div>
</form>
@endif
@endsection

@section('scripts')
<script>
const csrfToken = '{{ csrf_token() }}';

function toggleAll(cb) {
    document.querySelectorAll('.item-check').forEach(c => c.checked = cb.checked);
    updateSummary();
}

function updateSummary() {
    const checked = document.querySelectorAll('.item-check:checked');
    let total = 0;
    const sellers = new Set();
    checked.forEach(c => {
        const row = c.closest('tr');
        total += parseFloat(row.querySelector('[data-subtotal]').dataset.subtotal);
        sellers.add(c.dataset.seller);
    });
    // One shipping fee per store parcel, as charged at checkout.
    const option = document.getElementById('shippingOption').selectedOptions[0];
    const shipping = sellers.size * parseFloat(option ? option.dataset.fee : 0);
    const peso = n => '₱' + n.toLocaleString('en-PH', {minimumFractionDigits:2, maximumFractionDigits:2});
    document.getElementById('selectedCount').textContent = checked.length;
    document.getElementById('shippingAmount').textContent = peso(shipping);
    document.getElementById('totalAmount').textContent = peso(total + shipping);
    const button = document.getElementById('placeOrderBtn');
    button.disabled = checked.length === 0 || button.dataset.canOrder !== '1';
    const selectAll = document.getElementById('selectAll');
    if (selectAll) {
        selectAll.checked = checked.length === document.querySelectorAll('.item-check').length;
    }
}

document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.qty-input').forEach(function (input) {
        input.addEventListener('change', function () {
            const itemId = this.dataset.itemId;
            const quantity = Number(this.value || 1);
            if (!itemId || quantity < 1) return;

            fetch(`/buyer/cart/item/${itemId}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrfToken,
                    'Accept': 'application/json'
                },
                body: JSON.stringify({ quantity })
            }).then(async response => {
                if (!response.ok) {
                    const body = await response.json().catch(() => ({}));
                    throw new Error(body.errors?.quantity?.[0] || body.message || 'Unable to update quantity. Please try again.');
                }
                window.location.reload();
            }).catch(error => {
                alert(error.message);
                window.location.reload();
            });
        });
    });

    document.querySelectorAll('.remove-item-btn').forEach(function (button) {
        button.addEventListener('click', function () {
            const itemId = this.dataset.itemId;
            if (!itemId) return;
            if (!confirm('Remove this item from your cart?')) return;

            fetch(`/buyer/cart/item/${itemId}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-TOKEN': csrfToken,
                    'Accept': 'application/json'
                }
            }).then(response => {
                if (!response.ok) {
                    throw new Error('Unable to remove item');
                }
                window.location.reload();
            }).catch(() => {
                alert('Unable to remove this item. Please try again.');
            });
        });
    });
});
</script>
@endsection
