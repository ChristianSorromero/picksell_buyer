@extends('seller.layout')
@section('title', 'Options · ' . $product->name)

@section('content')
<div style="margin-bottom:1rem;"><a href="/seller/inventory" class="btn btn-outline btn-sm">← Back to Inventory</a></div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">{{ $product->name }} — Options</span></div>
        <div class="card-body" style="font-size:0.85rem;">
            <p style="color:#888;margin-top:0;">Buyers choose one option of each type (e.g. one Color and one Size). Each option has its own stock; an order needs stock in every option chosen <strong>and</strong> in the product's total stock ({{ $product->stock }}).
                Stock for a specific combination (e.g. only White in size L) can't be set yet.</p>
            @forelse($groups as $type => $options)
                <div style="font-weight:700;margin:0.8rem 0 0.4rem;">{{ $type }}</div>
                <table>
                    <thead><tr><th>Value</th><th>Stock</th><th></th></tr></thead>
                    <tbody>
                    @foreach($options as $option)
                        <tr>
                            <td colspan="2">
                                <form method="POST" action="{{ route('seller.variations.update', [$product, $option]) }}" style="display:flex;gap:0.4rem;align-items:center;">
                                    @csrf @method('PATCH')
                                    <input type="hidden" name="type" value="{{ $option->type }}">
                                    <input type="text" name="value" value="{{ $option->value }}" class="form-control" required maxlength="50" style="max-width:160px;">
                                    <input type="number" name="stock" value="{{ $option->stock }}" min="0" class="form-control" required style="max-width:90px;">
                                    <button class="btn btn-outline btn-sm">Save</button>
                                    @if($option->stock === 0)<span style="font-size:0.75rem;color:#dc2626;">Sold out</span>@endif
                                </form>
                            </td>
                            <td>
                                <form method="POST" action="{{ route('seller.variations.destroy', [$product, $option]) }}" onsubmit="return confirm('Remove {{ $option->type }}: {{ $option->value }}? Buyers who added it to their cart will need to choose again.')">
                                    @csrf @method('DELETE')
                                    <button class="btn btn-danger btn-sm">Remove</button>
                                </form>
                            </td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            @empty
                <p style="color:#888;">No options yet — buyers order this product as is.</p>
            @endforelse
        </div>
    </div>

    <div class="card">
        <div class="card-header"><span class="card-title">Add an Option</span></div>
        <div class="card-body">
            <form method="POST" action="{{ route('seller.variations.store', $product) }}">
                @csrf
                <div class="form-group">
                    <label class="form-label">Type</label>
                    <input type="text" name="type" class="form-control" list="variation-types" required maxlength="30" placeholder="e.g. Color, Size" value="{{ old('type') }}">
                    <datalist id="variation-types">
                        @foreach($groups->keys()->merge(['Color', 'Size'])->unique() as $type)<option value="{{ $type }}">@endforeach
                    </datalist>
                </div>
                <div class="form-group">
                    <label class="form-label">Value</label>
                    <input type="text" name="value" class="form-control" required maxlength="50" placeholder="e.g. White, L" value="{{ old('value') }}">
                </div>
                <div class="form-group">
                    <label class="form-label">Stock for this option</label>
                    <input type="number" name="stock" class="form-control" min="0" required value="{{ old('stock', 0) }}">
                </div>
                <button class="btn btn-coral">Add option</button>
            </form>
        </div>
    </div>
</div>
@endsection
