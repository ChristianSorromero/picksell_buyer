@extends('admin.layout')
@section('title', 'User Accounts')

@section('content')
<div class="card">
    <div class="card-header">
        <span class="card-title">All User Accounts</span>
        <form method="GET" class="filters">
            <input type="text" name="search" class="search-input" placeholder="Search name or email..." value="{{ $search }}">
            <select name="role" class="filter-select">
                <option value="all" {{ $role==='all'?'selected':'' }}>All Roles</option>
                <option value="buyer" {{ $role==='buyer'?'selected':'' }}>Buyer</option>
                <option value="seller" {{ $role==='seller'?'selected':'' }}>Seller</option>
                <option value="courier" {{ $role==='courier'?'selected':'' }}>Courier</option>
                    <option value="logistics" {{ $role==='logistics'?'selected':'' }}>Logistics Provider</option>
            </select>
            <select name="status" class="filter-select">
                <option value="all" {{ $status==='all'?'selected':'' }}>All Status</option>
                <option value="approved" {{ $status==='approved'?'selected':'' }}>Active</option>
                <option value="suspended" {{ $status==='suspended'?'selected':'' }}>Suspended</option>
                <option value="deactivated" {{ $status==='deactivated'?'selected':'' }}>Deactivated</option>
            </select>
            <button type="submit" class="btn btn-coral btn-sm">Search</button>
        </form>
    </div>
    <table>
        <thead>
            <tr><th>Name</th><th>Role</th><th>Email</th><th>Contact</th><th>Status</th><th>Joined</th><th>Actions</th></tr>
        </thead>
        <tbody>
        @forelse($users as $user)
        <tr>
            <td><strong>{{ $user->full_name }}</strong></td>
            <td><span class="badge badge-{{ $user->role }}">{{ ucfirst($user->role) }}</span></td>
            <td>{{ $user->email }}</td>
            <td>{{ $user->contact_no }}</td>
            <td><span class="badge badge-{{ $user->status }}">{{ ucfirst($user->status) }}</span></td>
            <td>{{ $user->created_at->forDisplay()->format('M d, Y') }}</td>
            <td>
                <div style="display:flex;gap:0.4rem;flex-wrap:wrap;">
                    @if($user->status !== 'approved')
                    <form method="POST" action="/admin/users/{{ $user->id }}/status">
                        @csrf @method('PATCH')
                        <input type="hidden" name="status" value="approved">
                        <button class="btn btn-success btn-sm">Activate</button>
                    </form>
                    @endif
                    @if($user->status !== 'suspended')
                    <form method="POST" action="/admin/users/{{ $user->id }}/status">
                        @csrf @method('PATCH')
                        <input type="hidden" name="status" value="suspended">
                        <button class="btn btn-danger btn-sm" onclick="return confirm('Suspend this account?')">Suspend</button>
                    </form>
                    @endif
                    @if($user->status !== 'deactivated')
                    <form method="POST" action="/admin/users/{{ $user->id }}/status">
                        @csrf @method('PATCH')
                        <input type="hidden" name="status" value="deactivated">
                        <button class="btn btn-outline btn-sm" onclick="return confirm('Deactivate this account?')">Deactivate</button>
                    </form>
                    @endif
                </div>
            </td>
        </tr>
        @empty
        <tr><td colspan="7" style="text-align:center;color:#888;padding:2rem;">No users found.</td></tr>
        @endforelse
        </tbody>
    </table>
    @if($users->hasPages())
    <div class="dashboard-pagination">{{ $users->withQueryString()->links() }}</div>
    @endif
</div>
@endsection
