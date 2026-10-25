<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Order;
use App\Models\Payout;
use App\Models\SellerTaxProfile;
use App\Models\User;
use App\Services\CodPayments;
use App\Services\Settlements;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;

/** Reconciliation, settlements and manual payouts. No money moves automatically. */
class AdminFinanceController extends Controller
{
    public function __construct(private Settlements $settlements) {}

    public function index()
    {
        [$start, $end] = $this->settlements->lastPeriod();

        return view('admin.finance', [
            'rec'         => $this->settlements->reconciliation(),
            'payouts'     => Payout::with('payee')->latest()->paginate(20),
            'sellers'     => User::where('role', 'seller')->where('status', 'approved')->orderBy('business_name')->get(),
            'taxProfiles' => SellerTaxProfile::with('verifiedBy')->get()->keyBy('seller_id'),
            'periodStart' => $start,
            'periodEnd'   => $end,
        ]);
    }

    public function settle(Request $request)
    {
        $count = $this->settlements->settleEligible($request->user());
        return back()->with('success', "{$count} order(s) settled.");
    }

    public function generate(Request $request)
    {
        $data = $request->validate(['period_start' => 'required|date', 'period_end' => 'required|date|after_or_equal:period_start|before:today']);
        $payouts = $this->settlements->generatePayouts(
            CarbonImmutable::parse($data['period_start'])->startOfDay(),
            CarbonImmutable::parse($data['period_end'])->endOfDay(),
            $request->user(),
        );
        return back()->with('success', $payouts->isEmpty() ? 'Nothing new to pay out for that period.' : "{$payouts->count()} payout(s) created for review.");
    }

    public function updatePayout(Request $request, Payout $payout)
    {
        $data = $request->validate([
            'action'       => 'required|in:approve,processing,complete,fail,cancel',
            'reference'    => 'required_if:action,complete|nullable|string|max:120',
            'disbursed_on' => 'required_if:action,complete|nullable|date',
            'reason'       => 'required_if:action,fail,cancel|nullable|string|max:500',
        ]);
        $admin = $request->user();

        match ($data['action']) {
            'approve'    => $this->settlements->approve($payout, $admin),
            'processing' => $this->settlements->markProcessing($payout, $admin),
            'complete'   => $this->settlements->complete($payout, $admin, $data['reference'], $data['disbursed_on']),
            'fail'       => $this->settlements->fail($payout, $admin, $data['reason']),
            'cancel'     => $this->settlements->cancel($payout, $admin, $data['reason']),
        };

        return back()->with('success', "Payout #{$payout->id} is now {$payout->status}.");
    }

    /** Records verified historical cash for an order delivered before COD tracking. */
    public function backfill(Request $request, Order $order, CodPayments $cod)
    {
        $data = $request->validate([
            'amount'       => 'required|numeric|min:0',
            'evidence'     => 'required|string|max:300',
            'reason'       => 'required|string|max:500',
            'collected_on' => 'nullable|date|before_or_equal:today',
        ]);
        $cod->backfillHistoricalCollection($order, $request->user(), (string) $data['amount'], $data['evidence'], $data['reason'], $data['collected_on'] ?? null);
        return back()->with('success', "Historical payment recorded for {$order->order_number}.");
    }

    public function unverifiable(Request $request, Order $order, CodPayments $cod)
    {
        $data = $request->validate(['note' => 'required|string|max:500']);
        $cod->markUnverifiable($order, $request->user(), $data['note']);
        return back()->with('success', "{$order->order_number} marked unverifiable; it stays out of settlement and refunds.");
    }

    /** Seller tax details for a future RR 16-2023 implementation (withholding stays off). */
    public function taxProfile(Request $request, User $seller)
    {
        abort_unless($seller->role === 'seller', 404);
        $data = $request->validate([
            'tin'                           => ['nullable', 'regex:/^\d{3}-?\d{3}-?\d{3}(-?\d{3,5})?$/'],
            'bir_cor_number'                => 'nullable|string|max:40',
            'sworn_declaration_year'        => 'nullable|integer|min:2024|max:2100',
            'sworn_declaration_received_on' => 'nullable|date|before_or_equal:today',
            'exemption_type'                => 'nullable|in:lower_rate,exempt_by_law,exempt_by_treaty',
            'exemption_reference'           => 'nullable|string|max:255',
            'notes'                         => 'nullable|string|max:1000',
            'verified'                      => 'nullable|boolean',
        ], ['tin.regex' => 'Enter the TIN as 000-000-000 or 000-000-000-00000.']);

        $profile = SellerTaxProfile::firstOrNew(['seller_id' => $seller->id]);
        $verified = (bool) ($data['verified'] ?? false);
        $profile->fill(collect($data)->except('verified')->all() + [
            'verified_by' => $verified ? $request->user()->id : null,
            'verified_at' => $verified ? now() : null,
        ])->save();
        AuditLog::record($profile, 'tax_profile_saved', null, $verified ? 'verified' : 'unverified', null, null, $request->user());

        return back()->with('success', "Tax details saved for {$seller->business_name}.");
    }

    /** Admin can also confirm cash a rider hands in, e.g. when no sorting-center staff is on duty. */
    public function remit(Request $request, User $courier, CodPayments $cod)
    {
        abort_unless($courier->role === 'courier', 404);
        $data = $request->validate(['order_ids' => 'required|array|min:1', 'order_ids.*' => 'integer']);
        $cents = $cod->confirmRemittance($courier, $data['order_ids'], $request->user());
        return back()->with('success', 'Confirmed ' . Money::format($cents) . " handed in by {$courier->full_name}.");
    }
}
