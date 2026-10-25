<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BuyerAddress;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** BUY-A03 Address Manager. */
class AddressController extends Controller
{
    private function rules(bool $partial = false): array
    {
        $req = $partial ? 'sometimes|required' : 'required';
        return [
            'label'          => "$req|in:home,work,other",
            'recipient_name' => "$req|string|max:120",
            'phone'          => [$partial ? 'sometimes' : 'required', 'regex:/^09\d{9}$/'],
            'province'       => "$req|string|max:120",
            'municipality'   => "$req|string|max:120",
            'barangay'       => "$req|string|max:120",
            'street'         => "$req|string|max:255",
            'house_no'       => 'nullable|string|max:60',
            'postal_code'    => ['nullable', 'regex:/^\d{4}$/'],
            'landmark'       => 'nullable|string|max:160',
            'is_default'     => 'sometimes|boolean',
        ];
    }

    private function messages(): array
    {
        return [
            'phone.regex'       => 'Enter a valid PH mobile number (e.g. 917 123 4567).',
            'postal_code.regex' => 'Postal codes have 4 digits.',
        ];
    }

    public function index(Request $request)
    {
        $addresses = $request->user()->addresses()->orderByDesc('is_default')->latest()->get();
        return response()->json(['addresses' => $addresses->map(fn ($a) => BuyerPresenter::address($a))]);
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->rules(), $this->messages());
        $user = $request->user();

        $address = DB::transaction(function () use ($user, $data) {
            $first = !$user->addresses()->exists();
            $makeDefault = $first || !empty($data['is_default']);
            if ($makeDefault) $user->addresses()->update(['is_default' => false]);

            return $user->addresses()->create(['is_default' => $makeDefault] + $data);
        });

        return response()->json(['message' => 'Address saved.', 'address' => BuyerPresenter::address($address)], 201);
    }

    public function update(Request $request, BuyerAddress $address)
    {
        abort_if($address->user_id !== $request->user()->id, 404);
        $data = $request->validate($this->rules(true), $this->messages());

        DB::transaction(function () use ($request, $address, $data) {
            if (!empty($data['is_default'])) {
                $request->user()->addresses()->whereKeyNot($address->id)->update(['is_default' => false]);
            }
            // The only address must stay the default.
            if (array_key_exists('is_default', $data) && !$data['is_default'] && $address->is_default) {
                unset($data['is_default']);
            }
            $address->update($data);
        });

        return response()->json(['message' => 'Address updated.', 'address' => BuyerPresenter::address($address->fresh())]);
    }

    public function destroy(Request $request, BuyerAddress $address)
    {
        abort_if($address->user_id !== $request->user()->id, 404);

        DB::transaction(function () use ($request, $address) {
            $wasDefault = $address->is_default;
            $address->delete();
            if ($wasDefault) {
                $request->user()->addresses()->latest()->first()?->update(['is_default' => true]);
            }
        });

        return $this->index($request);
    }
}
