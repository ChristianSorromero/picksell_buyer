<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\WishlistItem;
use App\Support\BuyerPresenter;
use App\Support\OrderStatus;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Account summary and profile edits on the shared `users` row. The profile address is where the
 * website books every delivery, so editing it here changes where new orders go.
 */
class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();

        $counts = collect(array_keys(OrderStatus::TABS))->mapWithKeys(fn ($t) => [$t => 0])->all();
        Order::where('buyer_id', $user->id)->get(['id', 'status', 'rating'])
            ->each(function (Order $o) use (&$counts) { $counts[OrderStatus::tab($o)]++; });

        return response()->json([
            'user'  => $this->userPayload($user),
            'stats' => [
                'order_counts'   => $counts,
                'wishlist_count' => WishlistItem::where('user_id', $user->id)->count(),
                'cart_count'     => (int) CartItem::whereHas('cart', fn ($q) => $q->where('buyer_id', $user->id))->sum('quantity'),
            ],
            'delivery_address' => BuyerPresenter::deliveryAddress($user),
        ]);
    }

    /** PATCH /buyer/profile — the website account page's fields, minus email. */
    public function update(Request $request)
    {
        $user = $request->user();
        $namePattern = "/^\\pL[\\pL\\s.'\\-]*$/u";
        $data = $request->validate([
            'first_name'     => ['required', 'string', 'min:2', 'max:50', "regex:{$namePattern}"],
            'last_name'      => ['required', 'string', 'min:2', 'max:50', "regex:{$namePattern}"],
            'middle_initial' => ['nullable', 'string', 'max:5', "regex:/^[\\pL.\\s]+$/u"],
            'sex'            => 'nullable|in:Male,Female',
            'birthday'       => ['required', 'date_format:Y-m-d', 'before_or_equal:-18 years'],
            'contact_no'     => ['required', 'regex:/^09\d{9}$/', Rule::unique('users', 'contact_no')->ignore($user->id)],
            'province'       => 'sometimes|required|string|max:100',
            'municipality'   => 'sometimes|required|string|max:100',
            'barangay'       => 'sometimes|required|string|max:100',
            'street'         => 'nullable|string|max:255',
            'house_no'       => 'nullable|string|max:100',
        ], [
            'first_name.regex'         => 'Use letters, spaces, hyphens, apostrophes or periods only.',
            'last_name.regex'          => 'Use letters, spaces, hyphens, apostrophes or periods only.',
            'birthday.before_or_equal' => 'You must be at least 18 years old.',
            'contact_no.regex'         => 'Enter a valid PH mobile number (e.g. 09171234567).',
            'contact_no.unique'        => 'This mobile number is already in use.',
        ]);

        $user->update($data + ['age' => \Carbon\Carbon::parse($data['birthday'])->age]);

        return response()->json(['message' => 'Profile updated.', 'user' => $this->userPayload($user->fresh())]);
    }

    public function password(Request $request)
    {
        $data = $request->validate([
            'current_password' => 'required|string',
            'password'         => ['required', 'confirmed', 'different:current_password', Password::min(8)->letters()->mixedCase()->numbers()->symbols()],
        ], ['password.different' => 'Choose a password different from your current one.']);

        if (! Hash::check($data['current_password'], $request->user()->password)) {
            return response()->json([
                'message' => 'Your current password is incorrect.',
                'errors'  => ['current_password' => ['Your current password is incorrect.']],
            ], 422);
        }

        $request->user()->update(['password' => Hash::make($data['password'])]);
        // Sign out every other device.
        $current = $request->user()->currentAccessToken();
        $currentId = $current instanceof PersonalAccessToken ? $current->id : null;
        $request->user()->tokens()->when($currentId, fn ($q) => $q->whereKeyNot($currentId))->delete();

        return response()->json(['message' => 'Password changed.']);
    }

    public function logout(Request $request)
    {
        $token = $request->user()->currentAccessToken();
        if ($token instanceof PersonalAccessToken) $token->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    private function userPayload($user): array
    {
        return [
            'id'             => $user->id,
            'first_name'     => $user->first_name,
            'last_name'      => $user->last_name,
            'middle_initial' => $user->middle_initial,
            'name'           => trim($user->first_name.' '.$user->last_name),
            'email'          => $user->email,
            'contact_no'     => $user->contact_no,
            'sex'            => $user->sex,
            'birthday'       => $user->birthday?->toDateString(),
            'province'       => $user->province,
            'municipality'   => $user->municipality,
            'barangay'       => $user->barangay,
            'street'         => $user->street,
            'house_no'       => $user->house_no,
            'member_since'   => BuyerPresenter::date($user->created_at),
        ];
    }
}
