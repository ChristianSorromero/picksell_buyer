<?php

namespace App\Http\Controllers;

use App\Models\Complaint;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Serves identity documents and dispute evidence from the private disk
 * (storage/app/private), only to people allowed to see them. Files stored
 * on the public disk before this change are still served — but only
 * through this check — until they are migrated.
 */
class DocumentController extends Controller
{
    private const USER_DOCS = [
        'id'     => 'id_upload',
        'permit' => 'business_permit',
        'orcr'   => 'or_cr_upload',
    ];

    public function userDocument(Request $request, User $user, string $type): StreamedResponse
    {
        $column = self::USER_DOCS[$type] ?? abort(404);
        $viewer = $request->user();

        $allowed = $viewer->role === 'admin'
            || $viewer->id === $user->id
            // Logistics partners review courier applicants.
            || ($viewer->role === 'logistics' && $user->role === 'courier');
        abort_unless($allowed, 403);

        return $this->stream($user->{$column});
    }

    public function complaintEvidence(Request $request, Complaint $complaint, int $index = 0): StreamedResponse
    {
        abort_unless($request->user()->role === 'admin' || $request->user()->id === $complaint->filed_by, 403);

        $paths = $complaint->evidence_paths ?: array_filter([$complaint->evidence_path]);
        return $this->stream($paths[$index] ?? null);
    }

    private function stream(?string $path): StreamedResponse
    {
        abort_if(!$path || str_contains($path, '..'), 404);

        foreach (['local', 'public'] as $disk) {
            if (Storage::disk($disk)->exists($path)) {
                return Storage::disk($disk)->response($path, basename($path), [
                    'Cache-Control'          => 'private, no-store',
                    'X-Content-Type-Options' => 'nosniff',
                    'Content-Disposition'    => 'inline; filename="' . basename($path) . '"',
                ]);
            }
        }
        abort(404);
    }
}
