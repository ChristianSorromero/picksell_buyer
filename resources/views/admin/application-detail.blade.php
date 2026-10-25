@extends('admin.layout')
@section('title', 'Review Application')

@section('content')
<div style="margin-bottom:1rem;">
    <a href="/admin/registrations" class="btn btn-outline btn-sm">← Back to Registrations</a>
</div>

<div class="grid-2">
    <!-- Applicant Info -->
    <div class="card">
        <div class="card-header">
            <span class="card-title">Applicant Information</span>
            <span class="badge badge-{{ $user->role }}">{{ ucfirst($user->role) }}</span>
        </div>
        <div class="card-body">
            @php
            $fields = [
                'Full Name'    => $user->full_name,
                'Sex'          => $user->sex,
                'Birthday'     => $user->birthday->format('F d, Y'),
                'Age'          => $user->age . ' years old',
                'Email'        => $user->email,
                'Contact No.'  => $user->contact_no,
                'Province'     => $user->province,
                'Municipality' => $user->municipality,
                'Barangay'     => $user->barangay,
                'Street'       => $user->street ?? '—',
                'House No.'    => $user->house_no ?? '—',
                'Applied'      => $user->created_at->forDisplay()->format('M d, Y h:i A'),
            ];
            if ($user->role === 'seller') {
                $fields['Business Name']    = $user->business_name;
                $fields['Line of Business'] = $user->line_of_business;
            }
            if ($user->role === 'courier') {
                $fields['Vehicle Type'] = $user->vehicle_type;
                $fields['Plate Number'] = $user->plate_number;
                $fields['Delivery Area'] = $user->delivery_area ?? '—';
            }
            @endphp
            <table style="font-size:0.88rem;">
                @foreach($fields as $label => $value)
                <tr>
                    <td style="font-weight:600;color:#888;padding:0.4rem 0.8rem 0.4rem 0;width:140px;">{{ $label }}</td>
                    <td style="padding:0.4rem 0;">{{ $value }}</td>
                </tr>
                @endforeach
            </table>
        </div>
    </div>

    <!-- Uploaded Documents -->
    <div>
        <div class="card" style="margin-bottom:1rem;">
            <div class="card-header"><span class="card-title">Uploaded Documents</span></div>
            <div class="card-body" style="display:flex;flex-direction:column;gap:0.8rem;">
                @if($user->id_upload)
                <div>
                    <div style="font-size:0.82rem;font-weight:600;margin-bottom:0.3rem;">Government-Issued ID</div>
                    <a href="{{ route('documents.user', [$user, 'id']) }}" target="_blank" class="btn btn-outline btn-sm">📎 View ID</a>
                </div>
                @endif
                @if($user->business_permit)
                <div>
                    <div style="font-size:0.82rem;font-weight:600;margin-bottom:0.3rem;">Business Permit</div>
                    <a href="{{ route('documents.user', [$user, 'permit']) }}" target="_blank" class="btn btn-outline btn-sm">📎 View Permit</a>
                </div>
                @endif
                @if($user->or_cr_upload)
                <div>
                    <div style="font-size:0.82rem;font-weight:600;margin-bottom:0.3rem;">OR/CR & Driver's License</div>
                    <a href="{{ route('documents.user', [$user, 'orcr']) }}" target="_blank" class="btn btn-outline btn-sm">📎 View OR/CR</a>
                </div>
                @endif
            </div>
        </div>

        <!-- Decision -->
        @if($user->status === 'pending')
        <div class="card">
            <div class="card-header"><span class="card-title">Decision</span></div>
            <div class="card-body">
                <!-- Approve -->
                <form method="POST" action="/admin/registrations/{{ $user->id }}/approve" style="margin-bottom:1rem;">
                    @csrf @method('PATCH')
                    <p style="font-size:0.85rem;color:#555;margin-bottom:0.8rem;">Approving will activate the account and notify the applicant via email.</p>
                    <button type="submit" class="btn btn-success" onclick="return confirm('Approve this application?')">✅ Approve Registration</button>
                </form>
                <hr style="border:none;border-top:1px solid #f0ebe0;margin-bottom:1rem;">
                <!-- Disapprove -->
                <form method="POST" action="/admin/registrations/{{ $user->id }}/disapprove">
                    @csrf @method('PATCH')
                    <div class="form-group">
                        <label class="form-label">Reason for Disapproval <span style="color:var(--coral)">*</span></label>
                        <textarea name="reason" class="form-control" placeholder="State the reason..." required></textarea>
                    </div>
                    <button type="submit" class="btn btn-danger" onclick="return confirm('Disapprove this application?')">❌ Disapprove Registration</button>
                </form>
            </div>
        </div>
        @else
        <div class="card">
            <div class="card-body">
                <p style="font-size:0.88rem;">Status: <span class="badge badge-{{ $user->status }}">{{ ucfirst($user->status) }}</span></p>
            </div>
        </div>
        @endif
    </div>
</div>
@endsection
