@extends('admin.layout')
@section('title', 'Complaints & Disputes')

@section('content')
<div class="card">
    <div class="card-header">
        <span class="card-title">Complaints & Disputes</span>
        <form method="GET" class="filters">
            <select name="status" class="filter-select" onchange="this.form.submit()">
                <option value="all"         {{ $status==='all'?'selected':'' }}>All Status</option>
                <option value="open"        {{ $status==='open'?'selected':'' }}>Open</option>
                <option value="under_review"{{ $status==='under_review'?'selected':'' }}>Under Review</option>
                <option value="resolved"    {{ $status==='resolved'?'selected':'' }}>Resolved</option>
                <option value="dismissed"   {{ $status==='dismissed'?'selected':'' }}>Dismissed</option>
            </select>
        </form>
    </div>
    <table>
        <thead>
            <tr><th>#</th><th>Filed By</th><th>Against</th><th>Subject</th><th>Status</th><th>Date</th><th>Action</th></tr>
        </thead>
        <tbody>
        @forelse($complaints as $c)
        <tr>
            <td>{{ $c->id }}</td>
            <td>
                <strong>{{ $c->filer->full_name ?? '—' }}</strong>
                <div style="font-size:0.75rem;color:#aaa;">{{ ucfirst($c->filer->role ?? '') }}</div>
            </td>
            <td>{{ $c->against->full_name ?? '—' }}</td>
            <td>{{ $c->subject }}</td>
            <td>
                @php
                $badgeMap = ['open'=>'badge-pending','under_review'=>'badge-pending','resolved'=>'badge-approved','dismissed'=>'badge-deactivated'];
                @endphp
                <span class="badge {{ $badgeMap[$c->status] ?? 'badge-pending' }}">{{ ucfirst(str_replace('_',' ',$c->status)) }}</span>
            </td>
            <td>{{ $c->created_at->forDisplay()->format('M d, Y') }}</td>
            <td><a href="/admin/complaints/{{ $c->id }}" class="btn btn-coral btn-sm">Review</a></td>
        </tr>
        @empty
        <tr><td colspan="7" style="text-align:center;color:#888;padding:2rem;">No complaints found.</td></tr>
        @endforelse
        </tbody>
    </table>
    @if($complaints->hasPages())
    <div class="dashboard-pagination">{{ $complaints->withQueryString()->links() }}</div>
    @endif
</div>
@endsection
