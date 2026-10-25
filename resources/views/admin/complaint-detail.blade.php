@extends('admin.layout')
@section('title', 'Review Complaint #{{ $complaint->id }}')

@section('content')
<div style="margin-bottom:1rem;">
    <a href="/admin/complaints" class="btn btn-outline btn-sm">← Back to Complaints</a>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-header"><span class="card-title">Complaint Details</span></div>
        <div class="card-body">
            <table style="font-size:0.88rem;">
                <tr><td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;width:140px;">Filed By</td><td>{{ $complaint->filer->full_name ?? '—' }} ({{ ucfirst($complaint->filer->role ?? '') }})</td></tr>
                <tr><td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;">Against</td><td>{{ $complaint->against->full_name ?? 'N/A' }}</td></tr>
                <tr><td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;">Subject</td><td>{{ $complaint->subject }}</td></tr>
                <tr><td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;">Filed On</td><td>{{ $complaint->created_at->forDisplay()->format('M d, Y h:i A') }}</td></tr>
                <tr><td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;">Status</td>
                    <td>
                        @php $badgeMap = ['open'=>'badge-pending','under_review'=>'badge-pending','resolved'=>'badge-approved','dismissed'=>'badge-deactivated']; @endphp
                        <span class="badge {{ $badgeMap[$complaint->status] ?? 'badge-pending' }}">{{ ucfirst(str_replace('_',' ',$complaint->status)) }}</span>
                    </td>
                </tr>
            </table>
            <div style="margin-top:1rem;">
                <div style="font-size:0.82rem;font-weight:600;margin-bottom:0.4rem;">Details</div>
                <div style="background:#fafaf8;border:1px solid #f0ebe0;border-radius:8px;padding:0.8rem;font-size:0.88rem;line-height:1.6;">{{ $complaint->details }}</div>
            </div>
            @if($complaint->evidence_path)
            <div style="margin-top:1rem;">
                <div style="font-size:0.82rem;font-weight:600;margin-bottom:0.4rem;">Evidence</div>
                <a href="{{ route('documents.complaint', $complaint) }}" target="_blank" class="btn btn-outline btn-sm">📎 View Evidence</a>
            </div>
            @endif
        </div>
    </div>

    <div class="card">
        <div class="card-header"><span class="card-title">Admin Resolution</span></div>
        <div class="card-body">
            <form method="POST" action="/admin/complaints/{{ $complaint->id }}">
                @csrf @method('PATCH')
                <div class="form-group">
                    <label class="form-label">Update Status</label>
                    <select name="status" class="form-control">
                        <option value="open"         {{ $complaint->status==='open'?'selected':'' }}>Open</option>
                        <option value="under_review" {{ $complaint->status==='under_review'?'selected':'' }}>Under Review</option>
                        <option value="resolved"     {{ $complaint->status==='resolved'?'selected':'' }}>Resolved</option>
                        <option value="dismissed"    {{ $complaint->status==='dismissed'?'selected':'' }}>Dismissed</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Admin Notes / Resolution</label>
                    <textarea name="admin_notes" class="form-control" rows="6" placeholder="Write your resolution or coordination notes...">{{ $complaint->admin_notes }}</textarea>
                </div>
                <div style="display:flex;gap:0.6rem;">
                    <button type="submit" class="btn btn-coral">💾 Save Resolution</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection
