<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Product;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class MobileAuthController extends Controller
{
    public function products(Request $request)
    {
        $query = Product::where('status', 'active')
            ->where('stock', '>', 0)
            ->with('seller');

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        if ($request->filled('search')) {
            $query->where('name', 'like', '%' . $request->search . '%');
        }

        $products = $query->latest()->get()->map(fn($p) => [
            'id'             => $p->id,
            'name'           => $p->name,
            'description'    => $p->description ?? '',
            'category'       => $p->category ?? '',
            'price'          => (float) $p->effective_price,
            'original_price' => $p->discount > 0 ? (float) $p->price : null,
            'stock'          => $p->stock,
            'seller_name'    => $p->seller?->business_name ?? $p->seller?->full_name ?? '',
            'seller_location'=> trim(($p->seller?->municipality ?? '') . ', ' . ($p->seller?->province ?? ''), ', '),
            'image'          => $p->image ? url('storage/' . $p->image) : null,
        ]);

        return response()->json(['products' => $products]);
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            'last_name'      => 'required|string|max:100',
            'first_name'     => 'required|string|max:100',
            'middle_initial' => 'nullable|string|max:5',
            'sex'            => 'required|in:Male,Female',
            'email'          => 'required|email|unique:users',
            'password'       => 'required|min:8|confirmed',
            'contact_no'     => ['required', 'regex:/^09\d{9}$/'],
            'birthday'       => 'required|date|before:-18 years',
            'province'       => 'required|string',
            'municipality'   => 'required|string',
            'barangay'       => 'required|string',
            'street'         => 'nullable|string|max:255',
            'house_no'       => 'nullable|string|max:100',
        ]);

        $user = User::create([
            'role'           => 'buyer',
            'status'         => 'pending',
            'last_name'      => $data['last_name'],
            'first_name'     => $data['first_name'],
            'middle_initial' => $data['middle_initial'] ?? null,
            'sex'            => $data['sex'],
            'email'          => $data['email'],
            'password'       => Hash::make($data['password']),
            'contact_no'     => $data['contact_no'],
            'birthday'       => $data['birthday'],
            'age'            => Carbon::parse($data['birthday'])->age,
            'province'       => $data['province'],
            'municipality'   => $data['municipality'],
            'barangay'       => $data['barangay'],
            'street'         => $data['street'] ?? null,
            'house_no'       => $data['house_no'] ?? null,
        ]);

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Registration submitted! Please wait for admin approval.',
            'token'   => $token,
            'user'    => ['id' => $user->id, 'name' => $user->full_name, 'email' => $user->email],
        ], 201);
    }

    public function uploadId(Request $request)
    {
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'id_file' => 'required|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ]);

        $user = User::findOrFail($request->user_id);
        $path = $request->file('id_file')->store('uploads/ids', 'public');
        $user->update(['id_upload' => $path]);

        return response()->json(['message' => 'ID uploaded successfully.']);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        if ($user->role !== 'buyer') {
            return response()->json(['message' => 'This app is for buyers only.'], 403);
        }

        if ($user->isPending()) {
            return response()->json(['message' => 'Your account is still pending approval. Please check your email.'], 403);
        }

        if ($user->status === 'disapproved') {
            return response()->json(['message' => 'Your registration was disapproved. Please contact support.'], 403);
        }

        if ($user->status === 'suspended') {
            return response()->json(['message' => 'Your account has been suspended. Please contact support.'], 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Login successful.',
            'token'   => $token,
            'user'    => ['id' => $user->id, 'name' => $user->full_name, 'email' => $user->email],
        ]);
    }
}
