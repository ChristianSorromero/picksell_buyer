<?php

namespace App\Http\Controllers;

use App\Models\Payout;
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
            'action'    => 'required|in:approve,processing,complete,fail,cancel',
            'reference' => 'required_if:action,complete|nullable|string|max:120',
            'reason'    => 'required_if:action,fail,cancel|nullable|string|max:500',
        ]);
        $admin = $request->user();

        match ($data['action']) {
            'approve'    => $this->settlements->approve($payout, $admin),
            'processing' => $this->settlements->markProcessing($payout, $admin),
            'complete'   => $this->settlements->complete($payout, $admin, $data['reference']),
            'fail'       => $this->settlements->fail($payout, $admin, $data['reason']),
            'cancel'     => $this->settlements->cancel($payout, $admin, $data['reason']),
        };

        return back()->with('success', "Payout #{$payout->id} is now {$payout->status}.");
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
