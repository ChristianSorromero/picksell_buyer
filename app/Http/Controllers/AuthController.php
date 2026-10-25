<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Carbon\Carbon;

class AuthController extends Controller
{
    public function showLogin()    { return view('auth.login'); }
    public function showRegister() { return view('auth.register'); }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (!$user || !Hash::check($credentials['password'], $user->password)) {
            return back()->withErrors(['email' => 'Invalid email or password.'])->onlyInput('email');
        }

        if ($user->isPending()) {
            return back()->withErrors(['email' => 'Your account is still pending approval. Please check your email.'])->onlyInput('email');
        }

        if ($user->status === 'disapproved') {
            return back()->withErrors(['email' => 'Your registration was disapproved. Please contact support.'])->onlyInput('email');
        }

        if ($user->status === 'suspended') {
            return back()->withErrors(['email' => 'Your account has been suspended. Please contact support.'])->onlyInput('email');
        }

        Auth::login($user, $request->boolean('remember'));
        $request->session()->regenerate();

        return redirect($this->redirectByRole($user->role));
    }

    public function register(Request $request)
    {
        $role = $request->input('role', 'buyer');

        $rules = [
            'role'           => 'required|in:buyer,seller,courier,logistics',
            'provider_type'  => 'required_if:role,logistics|nullable|in:company,individual',
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
            'id_upload'      => 'required|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ];

        if (in_array($role, ['seller', 'logistics'], true)) {
            $rules['business_name']    = 'required|string|max:255';
            $rules['line_of_business'] = 'required|string|max:255';
            $rules['business_permit']  = 'required|file|mimes:jpg,jpeg,png,pdf|max:5120';
        }

        if ($role === 'courier') {
            $rules['vehicle_type'] = 'required|string';
            $rules['plate_number'] = 'required|string|max:20';
            $rules['or_cr_upload'] = 'required|file|mimes:jpg,jpeg,png,pdf|max:5120';
            $rules['delivery_area'] = 'required|string|max:255';
        }

        $data = $request->validate($rules);

        $age = Carbon::parse($data['birthday'])->age;

        $idPath = $request->file('id_upload')->store('uploads/ids', 'local');

        $extra = [];
        if (in_array($role, ['seller', 'logistics'], true)) {
            $extra['business_name']    = $data['business_name'];
            $extra['line_of_business'] = $data['line_of_business'];
            $extra['business_permit']  = $request->file('business_permit')->store('uploads/permits', 'local');
        }
        if ($role === 'courier') {
            $extra['vehicle_type'] = $data['vehicle_type'];
            $extra['plate_number'] = $data['plate_number'];
            $extra['or_cr_upload'] = $request->file('or_cr_upload')->store('uploads/orcr', 'local');
            $extra['delivery_area'] = $data['delivery_area'];
        }

        User::create(array_merge([
            'role'           => $role,
            'provider_type'  => $role === 'logistics' ? $data['provider_type'] : null,
            'status'         => 'pending',
            'last_name'      => $data['last_name'],
            'first_name'     => $data['first_name'],
            'middle_initial' => $data['middle_initial'] ?? null,
            'sex'            => $data['sex'],
            'email'          => $data['email'],
            'password'       => Hash::make($data['password']),
            'contact_no'     => $data['contact_no'],
            'birthday'       => $data['birthday'],
            'age'            => $age,
            'province'       => $data['province'],
            'municipality'   => $data['municipality'],
            'barangay'       => $data['barangay'],
            'street'         => $data['street'] ?? null,
            'house_no'       => $data['house_no'] ?? null,
            'id_upload'      => $idPath,
        ], $extra));

        return redirect('/login')->with('success', 'Registration submitted! Please wait for admin approval. You will be notified via email.');
    }

    public function showForgotPassword() { return view('auth.forgot-password'); }

    public function sendResetLink(Request $request)
    {
        $request->validate(['email' => 'required|email']);
        $status = Password::sendResetLink($request->only('email'));
        return $status === Password::RESET_LINK_SENT
            ? back()->with('success', 'Password reset link sent to your email.')
            : back()->withErrors(['email' => __($status)]);
    }

    public function showResetPassword(string $token)
    {
        return view('auth.reset-password', ['token' => $token]);
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'token'    => 'required',
            'email'    => 'required|email',
            'password' => 'required|min:8|confirmed',
        ]);

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill(['password' => Hash::make($password)])->save();
            }
        );

        return $status === Password::PASSWORD_RESET
            ? redirect('/login')->with('success', 'Password reset successfully. Please log in.')
            : back()->withErrors(['email' => __($status)]);
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect('/');
    }

    public function deleteAccount(Request $request)
    {
        $request->validate(['password' => 'required|string']);
        $user = $request->user();

        if (!Hash::check($request->password, $user->password)) {
            return back()->withErrors(['password' => 'The password is incorrect.']);
        }

        Auth::logout();
        $user->delete();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/')->with('success', 'Your account has been deleted.');
    }

    private function redirectByRole(string $role): string
    {
        return match($role) {
            'admin'   => '/admin/dashboard',
            'logistics' => '/logistics/dashboard',
            'seller'  => '/seller/dashboard',
            'courier' => '/courier/dashboard',
            default   => '/buyer/dashboard',
        };
    }
}
