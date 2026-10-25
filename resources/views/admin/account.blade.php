@extends('admin.layout')
@section('title', 'My Account')

@section('styles')
<style>
    .account-page .card { position: relative; border: 1px solid rgba(232,71,42,.28); box-shadow: 0 8px 24px rgba(232,71,42,.08); }
    .account-page .card::before { content: ''; position: absolute; inset: 0 0 auto; height: 3px; background: var(--coral); }
    .account-page .btn { box-shadow: 0 0 0 1px rgba(232,71,42,.18), 0 6px 16px rgba(232,71,42,.2); transition: transform .2s, box-shadow .2s, background .2s; }
    .account-page .btn:hover { transform: translateY(-2px); box-shadow: 0 0 0 2px rgba(232,71,42,.2), 0 10px 24px rgba(232,71,42,.32); }
    .account-page .danger-card { border: 1px solid #ef4444; border-radius: 16px; background: inherit; box-shadow: 0 8px 24px rgba(239,68,68,.08); }
    .account-page .danger-card::before { display: none; }
    .account-page .danger-card .card-header { border-bottom: 0; padding-bottom: 0.35rem; }
    .account-page .danger-card .card-title { color: #ff4545; }
    .account-page .danger-card .card-body { padding-top: 0.35rem; }
    .account-page .danger-card .btn-danger { background: #ff4545; border: 0; color: #fff; box-shadow: 0 8px 18px rgba(255,69,69,.35); }
    .account-page .danger-card .btn-danger:hover { background: #ff5d5d; box-shadow: 0 10px 24px rgba(255,69,69,.5); }
</style>
@endsection

@section('content')
<div class="account-page">
    <div class="card">
        <div class="card-header"><span class="card-title"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:6px;"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>Profile Information</span></div>
        <div class="card-body">
            <form method="POST" action="/admin/account">
                @csrf @method('PATCH')
                <div class="form-group">
                    <label class="form-label">First Name</label>
                    <input type="text" name="first_name" class="form-control" value="{{ auth()->user()->first_name }}" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Last Name</label>
                    <input type="text" name="last_name" class="form-control" value="{{ auth()->user()->last_name }}" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Email Address</label>
                    <input type="email" name="email" class="form-control" value="{{ auth()->user()->email }}" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Contact No.</label>
                    <input type="text" name="contact_no" class="form-control" value="{{ auth()->user()->contact_no }}" required>
                </div>
                <button type="submit" class="btn btn-coral"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:4px;"><path d="M17 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7l-4-4zm-5 16a3 3 0 1 1 0-6 3 3 0 0 1 0 6zm3-10H5V5h10v4z"/></svg>Save Changes</button>
            </form>
        </div>
    </div>

    <div class="card">
        <div class="card-header"><span class="card-title"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:6px;"><path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg>Change Password</span></div>
        <div class="card-body">
            <form method="POST" action="/admin/account/password">
                @csrf @method('PATCH')
                <div class="form-group">
                    <label class="form-label">Current Password</label>
                    <input type="password" name="current_password" class="form-control" required>
                    @error('current_password')<div style="color:#c0392b;font-size:0.78rem;margin-top:0.25rem;">{{ $message }}</div>@enderror
                </div>
                <div class="form-group">
                    <label class="form-label">New Password</label>
                    <input type="password" name="password" class="form-control" placeholder="Min. 8 characters" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Confirm New Password</label>
                    <input type="password" name="password_confirmation" class="form-control" required>
                </div>
                <button type="submit" class="btn btn-coral"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:4px;"><path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg>Update Password</button>
            </form>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:6px;"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>Account Details</span></div>
    <div class="card-body">
        <table style="font-size:0.88rem;">
            <tr><td style="font-weight:600;color:#888;padding:0.4rem 1rem 0.4rem 0;width:160px;">Role</td><td><span class="badge" style="background:#fff3f0;color:var(--coral);">Administrator</span></td></tr>
            <tr><td style="font-weight:600;color:#888;padding:0.4rem 1rem 0.4rem 0;">Status</td><td><span class="badge badge-approved">Active</span></td></tr>
            <tr><td style="font-weight:600;color:#888;padding:0.4rem 1rem 0.4rem 0;">Member Since</td><td>{{ auth()->user()->created_at->format('F d, Y') }}</td></tr>
        </table>
    </div>
</div>

<div class="account-page" style="margin-top:1.5rem;">
    <div class="card danger-card">
        <div class="card-header"><span class="card-title">Delete Account</span></div>
        <div class="card-body">
            <p style="font-size:0.88rem;color:#888;margin-bottom:1rem;">Permanently delete your administrator account. Your personal details are erased; records you handled stay on file.</p>
            <form method="POST" action="{{ route('account.delete') }}" onsubmit="return confirm('Delete your account permanently? This cannot be undone.')">
                @csrf @method('DELETE')
                <input type="password" name="password" class="form-control" placeholder="Confirm your password" required style="margin-bottom:.7rem;max-width:360px;">
                <button type="submit" class="btn btn-danger">Delete Account</button>
            </form>
        </div>
    </div>
</div>
@endsection
