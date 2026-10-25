@extends('admin.layout')
@section('title', 'Seller Compliance')

@section('content')
<div class="card">
    <div class="card-header"><span class="card-title">Active Sellers — Compliance Monitor</span></div>
    <table>
        <thead>
            <tr><th>Seller</th><th>Business Name</th><th>Category</th><th>Email</th><th>Joined</th><th>Actions</th></tr>
        </thead>
        <tbody>
        @forelse($sellers as $seller)
        <tr>
            <td><strong>{{ $seller->full_name }}</strong></td>
            <td>{{ $seller->business_name ?? '—' }}</td>
            <td><span class="badge badge-seller">{{ $seller->line_of_business ?? '—' }}</span></td>
            <td>{{ $seller->email }}</td>
            <td>{{ $seller->created_at->forDisplay()->format('M d, Y') }}</td>
            <td>
                <div style="display:flex;gap:0.4rem;flex-wrap:wrap;">
                    <!-- Warn -->
                    <button class="btn btn-outline btn-sm" onclick="openWarn({{ $seller->id }}, '{{ $seller->full_name }}')">⚠️ Warn</button>
                    <!-- Suspend -->
                    <form method="POST" action="/admin/users/{{ $seller->id }}/status">
                        @csrf @method('PATCH')
                        <input type="hidden" name="status" value="suspended">
                        <button class="btn btn-danger btn-sm" onclick="return confirm('Suspend {{ $seller->full_name }}?')">Suspend</button>
                    </form>
                </div>
            </td>
        </tr>
        @empty
        <tr><td colspan="6" style="text-align:center;color:#888;padding:2rem;">No sellers found.</td></tr>
        @endforelse
        </tbody>
    </table>
    @if($sellers->hasPages())
    <div class="dashboard-pagination">{{ $sellers->withQueryString()->links() }}</div>
    @endif
</div>

<!-- Warn Modal -->
<div id="warnModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:200;align-items:center;justify-content:center;">
    <div style="background:#fff;border-radius:12px;padding:2rem;width:100%;max-width:440px;margin:1rem;">
        <h3 style="margin-bottom:1rem;font-size:1rem;">⚠️ Issue Warning to <span id="warnName"></span></h3>
        <form method="POST" id="warnForm">
            @csrf @method('PATCH')
            <div class="form-group">
                <label class="form-label">Warning Message <span style="color:var(--coral)">*</span></label>
                <textarea name="warning" class="form-control" placeholder="Describe the violation..." required></textarea>
            </div>
            <div style="display:flex;gap:0.6rem;justify-content:flex-end;">
                <button type="button" class="btn btn-outline" onclick="closeWarn()">Cancel</button>
                <button type="submit" class="btn btn-coral">Send Warning</button>
            </div>
        </form>
    </div>
</div>

<script>
function openWarn(id, name) {
    document.getElementById('warnName').textContent = name;
    document.getElementById('warnForm').action = '/admin/compliance/' + id + '/warn';
    document.getElementById('warnModal').style.display = 'flex';
}
function closeWarn() {
    document.getElementById('warnModal').style.display = 'none';
}
</script>
@endsection
