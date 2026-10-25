@extends('admin.layout')
@section('title', 'Manage Registrations')

@section('content')
<div class="card">
    <div class="card-header">
        <span class="card-title">Registration Applications</span>
        <form method="GET" class="filters">
            <select name="role" class="filter-select" onchange="this.form.submit()">
                <option value="all" {{ $role==='all'?'selected':'' }}>All Roles</option>
                <option value="buyer" {{ $role==='buyer'?'selected':'' }}>Buyer</option>
                <option value="seller" {{ $role==='seller'?'selected':'' }}>Seller</option>
                <option value="courier" {{ $role==='courier'?'selected':'' }}>Courier</option>
                    <option value="logistics" {{ $role==='logistics'?'selected':'' }}>Logistics Provider</option>
            </select>
            <select name="status" class="filter-select" onchange="this.form.submit()">
                <option value="pending" {{ $status==='pending'?'selected':'' }}>Pending</option>
                <option value="approved" {{ $status==='approved'?'selected':'' }}>Approved</option>
                <option value="disapproved" {{ $status==='disapproved'?'selected':'' }}>Disapproved</option>
                <option value="all" {{ $status==='all'?'selected':'' }}>All Status</option>
            </select>
        </form>
    </div>
    <table>
        <thead>
            <tr><th>Name</th><th>Role</th><th>Email</th><th>Contact</th><th>Applied</th><th>Status</th><th>Action</th></tr>
        </thead>
        <tbody>
        @forelse($users as $user)
        <tr>
            <td><strong>{{ $user->full_name }}</strong></td>
            <td><span class="badge badge-{{ $user->role }}">{{ ucfirst($user->role) }}</span></td>
            <td>{{ $user->email }}</td>
            <td>{{ $user->contact_no }}</td>
            <td>{{ $user->created_at->forDisplay()->format('M d, Y') }}</td>
            <td><span class="badge badge-{{ $user->status }}">{{ ucfirst($user->status) }}</span></td>
            <td><a href="/admin/registrations/{{ $user->id }}" class="btn btn-coral btn-sm">Review</a></td>
        </tr>
        @empty
        <tr><td colspan="7" style="text-align:center;color:#888;padding:2rem;">No applications found.</td></tr>
        @endforelse
        </tbody>
    </table>
    @if($users->hasPages())
    <div class="dashboard-pagination">{{ $users->withQueryString()->links() }}</div>
    @endif
</div>
@endsection
