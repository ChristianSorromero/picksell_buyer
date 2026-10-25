@extends('admin.layout')
@section('title', 'Platform Settings')

@section('content')
<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:6px;"><path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V8l8 5 8-5v10zm-8-7L4 6h16l-8 5z"/></svg>Post Announcement</span></div>
        <div class="card-body">
            <form method="POST" action="/admin/settings">
                @csrf
                <div class="form-group">
                    <label class="form-label">Announcement Title</label>
                    <input type="text" name="announcement_title" class="form-control" placeholder="e.g. System Maintenance Notice" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Announcement Message</label>
                    <textarea name="announcement" class="form-control" rows="4" placeholder="Write your announcement here..." required></textarea>
                </div>
                <div class="form-group">
                    <label class="form-label">Audience</label>
                    <select name="audience" class="form-control">
                        <option value="all">All Users</option>
                        <option value="buyer">Buyers Only</option>
                        <option value="seller">Sellers Only</option>
                        <option value="courier">Couriers Only</option>
                    </select>
                </div>
                <button type="submit" class="btn btn-coral">Post Announcement</button>
            </form>

            @if($announcements->isNotEmpty())
            <div style="margin-top:1.5rem;border-top:1px solid #f0ebe0;padding-top:1.2rem;">
                <div style="font-size:0.8rem;font-weight:700;color:#888;text-transform:uppercase;letter-spacing:0.05em;margin-bottom:0.8rem;">Posted Announcements</div>
                @foreach($announcements as $ann)
                <div style="display:flex;align-items:flex-start;gap:0.8rem;padding:0.8rem 0;border-bottom:1px solid #f8f4ee;">
                    <div style="flex:1;">
                        <div style="font-size:0.88rem;font-weight:700;">{{ $ann->title }} <span style="font-size:0.72rem;font-weight:400;color:#aaa;margin-left:0.4rem;">{{ ucfirst($ann->audience) }}</span></div>
                        <div style="font-size:0.82rem;color:#666;margin-top:0.2rem;">{{ $ann->message }}</div>
                        <div style="font-size:0.72rem;color:#bbb;margin-top:0.3rem;">{{ $ann->created_at->forDisplay()->format('M d, Y h:i A') }} &nbsp;·&nbsp; {{ $ann->active ? 'Active' : 'Hidden' }}</div>
                    </div>
                    <div style="display:flex;gap:0.4rem;flex-shrink:0;">
                        <form method="POST" action="/admin/settings/announcements/{{ $ann->id }}/toggle">
                            @csrf @method('PATCH')
                            <button class="btn btn-outline btn-sm">{{ $ann->active ? 'Hide' : 'Show' }}</button>
                        </form>
                        <form method="POST" action="/admin/settings/announcements/{{ $ann->id }}">
                            @csrf @method('DELETE')
                            <button class="btn btn-danger btn-sm">Delete</button>
                        </form>
                    </div>
                </div>
                @endforeach
            </div>
            @endif
        </div>
    </div>

    <div class="card">
        <div class="card-header"><span class="card-title">Platform Policies</span></div>
        <div class="card-body">
            <form method="POST" action="/admin/settings">
                @csrf
                <div class="form-group">
                    <label class="form-label">Terms of Service</label>
                    <textarea name="policy" class="form-control" rows="6" placeholder="Write Terms of Service content...">{{ $tos }}</textarea>
                </div>
                <div class="form-group">
                    <label class="form-label">Privacy Policy</label>
                    <textarea name="privacy" class="form-control" rows="6" placeholder="Write Privacy Policy content...">{{ $privacy }}</textarea>
                </div>
                <button type="submit" class="btn btn-coral">Save Policies</button>
            </form>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header"><span class="card-title"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:6px;"><path d="M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7.01 7.01 0 0 0-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.47.47 0 0 0-.59.22L2.74 8.87a.47.47 0 0 0 .12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.37 1.04.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.57 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.47.47 0 0 0-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>General Settings</span></div>
    <div class="card-body">
        <form method="POST" action="/admin/settings">
            @csrf
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;">
                <div class="form-group">
                    <label class="form-label">Platform Name</label>
                    <input type="text" class="form-control" value="PickSell">
                </div>
                <div class="form-group">
                    <label class="form-label">Support Email</label>
                    <input type="email" class="form-control" value="support@picksell.ph">
                </div>
                <div class="form-group">
                    <label class="form-label">Commission Rate (%)</label>
                    <input type="number" class="form-control" value="10" min="0" max="100">
                </div>
                <div class="form-group">
                    <label class="form-label">Max File Upload Size (MB)</label>
                    <input type="number" class="form-control" value="5">
                </div>
            </div>
            <button type="submit" class="btn btn-coral"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" viewBox="0 0 24 24" style="vertical-align:middle;margin-right:4px;"><path d="M17 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7l-4-4zm-5 16a3 3 0 1 1 0-6 3 3 0 0 1 0 6zm3-10H5V5h10v4z"/></svg>Save Settings</button>
        </form>
    </div>
</div>
@endsection
