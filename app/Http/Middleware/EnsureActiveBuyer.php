<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Guards the mobile buyer API: only approved, verified buyers get through.
 * Blocks other roles that arrive with a web session (statefulApi) and
 * buyers suspended after their token was issued.
 */
class EnsureActiveBuyer
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || $user->role !== 'buyer') {
            return response()->json(['message' => 'This app is for buyers only.'], 403);
        }

        if ($user->status !== 'approved') {
            // Suspended / disapproved accounts lose API access immediately.
            $token = $user->currentAccessToken();
            if ($token instanceof \Laravel\Sanctum\PersonalAccessToken) $token->delete();
            return response()->json([
                'message' => $user->status === 'suspended'
                    ? 'Your account has been suspended. Please contact support.'
                    : 'Your account is not active. Please contact support.',
            ], 401);
        }

        return $next($request);
    }
}
