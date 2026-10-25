<?php

namespace App\Http\Controllers;

use App\Models\DeliveryAttempt;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/** Proof-of-delivery photos are private: admins and sorting-center staff only. */
class DeliveryProofController extends Controller
{
    public function photo(Request $request, DeliveryAttempt $attempt)
    {
        $user = $request->user();
        abort_unless(in_array($user->role, ['admin', 'logistics'], true) && ($user->role === 'admin' || $user->isApproved()), 403);
        abort_unless($attempt->proof_photo_path && Storage::disk('local')->exists($attempt->proof_photo_path), 404);
        return Storage::disk('local')->response($attempt->proof_photo_path);
    }
}
