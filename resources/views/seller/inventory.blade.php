@extends('seller.layout')
@section('title', 'Inventory')

@section('content')
<div class="card">
    <div class="card-header">
        <span class="card-title">Product Inventory</span>
        <div class="filters">
            <form method="GET" style="display:flex;gap:0.5rem;flex-wrap:wrap;">
                <input type="text" name="search" data-product-search value="{{ $search }}" placeholder="Search products..." class="search-input">
                <select name="status" class="filter-select" onchange="this.form.submit()">
                    <option value="all" {{ $status==='all'?'selected':'' }}>All Status</option>
                    <option value="active" {{ $status==='active'?'selected':'' }}>Active</option>
                    <option value="archived" {{ $status==='archived'?'selected':'' }}>Archived</option>
                </select>
                <button type="submit" class="btn btn-outline btn-sm">Search</button>
            </form>
            <button class="btn btn-coral btn-sm" onclick="openModal('addModal')">+ Add Product</button>
        </div>
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead>
                <tr>
                    <th>Product</th><th>Category</th><th>Price</th><th>Discount</th><th>Voucher</th><th>Stock</th><th>Status</th><th>Actions</th>
                </tr>
            </thead>
            <tbody>
            @forelse($products as $product)
            <tr>
                <td>
                    <div style="display:flex;align-items:center;gap:0.6rem;">
                        @if($product->image)
                            <img src="{{ Storage::url($product->image) }}" style="width:36px;height:36px;object-fit:cover;border-radius:6px;">
                        @else
                            <div style="width:36px;height:36px;background:#f0ebe0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:1.2rem;">📦</div>
                        @endif
                        <div>
                            <div style="font-weight:600;">{{ $product->name }}</div>
                            <div style="font-size:0.75rem;color:#888;">{{ Str::limit($product->description, 40) }}</div>
                        </div>
                    </div>
                </td>
                <td>{{ $product->category ?? '—' }}</td>
                <td>₱{{ number_format($product->price, 2) }}</td>
                <td>{{ $product->discount > 0 ? $product->discount.'%' : '—' }}</td>
                <td>{{ $product->voucher_code ? $product->voucher_code.' ('.$product->voucher_discount.'%)' : '—' }}</td>
                <td>
                    <span style="font-weight:600;{{ $product->stock <= 5 ? 'color:#dc2626;' : '' }}">{{ $product->stock }}</span>
                    @if($product->stock <= 5 && $product->stock > 0)<span style="font-size:0.72rem;color:#dc2626;"> Low</span>@endif
                    @if($product->stock == 0)<span style="font-size:0.72rem;color:#dc2626;"> Out</span>@endif
                </td>
                <td><span class="badge badge-{{ $product->status }}">{{ $product->status }}</span></td>
                <td>
                    <div style="display:flex;gap:0.4rem;">
                        <button class="btn btn-outline btn-sm" onclick="openEditModal({{ $product->id }}, {{ json_encode($product) }})">Edit</button>
                        <a href="{{ route('seller.variations', $product) }}" class="btn btn-outline btn-sm">Options ({{ $product->variations_count ?? $product->variations()->count() }})</a>
                        <form method="POST" action="/seller/inventory/{{ $product->id }}/archive">
                            @csrf @method('PATCH')
                            <button type="submit" class="btn btn-sm {{ $product->status==='archived' ? 'btn-success' : 'btn-danger' }}">
                                {{ $product->status==='archived' ? 'Restore' : 'Archive' }}
                            </button>
                        </form>
                    </div>
                </td>
            </tr>
            @empty
            <tr><td colspan="8" style="text-align:center;color:#aaa;padding:2rem;">No products found.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($products->hasPages())
    <div class="dashboard-pagination">{{ $products->withQueryString()->links() }}</div>
    @endif
</div>

<!-- Add Product Modal -->
<div class="modal-overlay" id="addModal">
    <div class="modal">
        <div class="modal-title">Add New Product</div>
        <form method="POST" action="/seller/inventory" enctype="multipart/form-data">
            @csrf
            @include('seller._product-form')
            <div class="modal-footer">
                <button type="button" class="btn btn-outline" onclick="closeModal('addModal')">Cancel</button>
                <button type="submit" class="btn btn-coral">Add Product</button>
            </div>
        </form>
    </div>
</div>

<!-- Edit Product Modal -->
<div class="modal-overlay" id="editModal">
    <div class="modal">
        <div class="modal-title">Edit Product</div>
        <form method="POST" id="editForm" enctype="multipart/form-data">
            @csrf @method('PATCH')
            @include('seller._product-form', ['edit' => true])
            <div class="modal-footer">
                <button type="button" class="btn btn-outline" onclick="closeModal('editModal')">Cancel</button>
                <button type="submit" class="btn btn-coral">Save Changes</button>
            </div>
        </form>
    </div>
</div>
@endsection

@section('scripts')
<script>
function openModal(id) { document.getElementById(id).classList.add('open'); }
function closeModal(id) { document.getElementById(id).classList.remove('open'); }
document.querySelectorAll('.modal-overlay').forEach(m => {
    m.addEventListener('click', e => { if (e.target === m) m.classList.remove('open'); });
});
function openEditModal(id, p) {
    const f = document.getElementById('editForm');
    f.action = '/seller/inventory/' + id;
    f.querySelector('[name=name]').value = p.name;
    f.querySelector('[name=description]').value = p.description || '';
    f.querySelector('[name=category]').value = p.category || '';
    f.querySelector('[name=price]').value = p.price;
    f.querySelector('[name=discount]').value = p.discount || 0;
    f.querySelector('[name=voucher_code]').value = p.voucher_code || '';
    f.querySelector('[name=voucher_discount]').value = p.voucher_discount || 0;
    f.querySelector('[name=stock]').value = p.stock;
    openModal('editModal');
}
</script>
@endsection
