@extends('admin.layout')
@section('title', 'Returns & Refunds')

@section('content')
@php
    $badge = ['requested'=>'badge-pending','info_requested'=>'badge-pending','with_seller'=>'badge-processing','proposed'=>'badge-processing',
              'escalated'=>'badge-suspended','resolved'=>'badge-processing','completed'=>'badge-approved','rejected'=>'badge-deactivated'];
    $filters = ['needs_admin' => 'Needs admin', 'all' => 'All'] + \App\Models\ReturnRequest::STAGE_LABELS;
@endphp
<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Returns & Refunds</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.2rem;">Admin reviews every request first, then hands it to the seller. Escalations come back here for a final decision.</div>
        </div>
        <form method="GET">
            <select name="status" class="filter-select" onchange="this.form.submit()">
                @foreach($filters as $value => $label)
                    <option value="{{ $value }}" @selected($status === $value)>{{ $label }}</option>
                @endforeach
            </select>
        </form>
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>#</th><th>Order</th><th>Buyer</th><th>Seller</th><th>Reason</th><th>Requested</th><th>Stage</th><th></th></tr></thead>
            <tbody>
            @forelse($returns as $r)
                <tr>
                    <td>#{{ $r->id }}</td>
                    <td>{{ $r->order->order_number }}<div style="font-size:0.75rem;color:#888;">{{ $r->quantity }} × {{ $r->order->product_name }}</div></td>
                    <td>{{ $r->buyer->full_name ?? '—' }}</td>
                    <td>{{ $r->order->seller->business_name ?? $r->order->seller->full_name ?? '—' }}</td>
                    <td>{{ $r->reason }}</td>
                    <td>{{ $r->created_at->forDisplay()->format('M d, Y') }}</td>
                    <td><span class="badge {{ $badge[$r->status] ?? 'badge-pending' }}">{{ \App\Models\ReturnRequest::STAGE_LABELS[$r->status] ?? $r->status }}</span></td>
                    <td><a href="{{ route('admin.returns.show', $r) }}" class="btn btn-outline btn-sm">Review</a></td>
                </tr>
            @empty
                <tr><td colspan="8" style="text-align:center;color:#888;padding:2rem;">No return requests here.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($returns->hasPages())<div style="padding:1rem;">{{ $returns->links() }}</div>@endif
</div>
@endsection
