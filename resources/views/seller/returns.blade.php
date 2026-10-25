@extends('seller.layout')
@section('title', 'Returns')

@section('content')
<div class="card">
    <div class="card-header">
        <div>
            <span class="card-title">Returns & Refunds</span>
            <div style="font-size:0.78rem;color:#888;margin-top:0.2rem;">Requests reach you after Picksell has reviewed them. Propose a resolution; if you and the buyer can't agree, Picksell decides.</div>
        </div>
    </div>
    <div style="overflow-x:auto;">
        <table>
            <thead><tr><th>#</th><th>Order</th><th>Buyer</th><th>Reason</th><th>Stage</th><th></th></tr></thead>
            <tbody>
            @forelse($returns as $r)
                <tr>
                    <td>#{{ $r->id }}</td>
                    <td>{{ $r->order->order_number }}<div style="font-size:0.75rem;color:#888;">{{ $r->quantity }} × {{ $r->order->product_name }}</div></td>
                    <td>{{ $r->buyer->full_name ?? '—' }}</td>
                    <td>{{ $r->reason }}</td>
                    <td>{{ \App\Models\ReturnRequest::STAGE_LABELS[$r->status] ?? $r->status }}
                        @if($r->status === 'with_seller' || $r->needsItemReceipt() || ($r->status === 'resolved' && $r->resolution_type === 'replacement' && !$r->replacement_sent_at))
                            <div style="font-size:0.75rem;color:#b45309;">Needs your action</div>
                        @endif
                    </td>
                    <td><a href="{{ route('seller.returns.show', $r) }}" class="btn btn-outline btn-sm">Open</a></td>
                </tr>
            @empty
                <tr><td colspan="6" style="text-align:center;color:#888;padding:2rem;">No return requests.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @if($returns->hasPages())<div style="padding:1rem;">{{ $returns->links() }}</div>@endif
</div>
@endsection
