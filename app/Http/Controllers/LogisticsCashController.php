<?php

namespace App\Http\Controllers;

use App\Models\ReturnRequest;
use App\Models\User;
use App\Services\CodPayments;
use App\Services\Ledger;
use App\Services\ReturnWorkflow;
use App\Support\Money;
use Illuminate\Http\Request;

/** Sorting-center cash desk: COD hand-ins from riders and refund cash going out. */
class LogisticsCashController extends Controller
{
    public function index(CodPayments $cod, Ledger $ledger)
    {
        $awaiting = $cod->awaitingRemittance(auth()->id());

        return view('logistics.cash', [
            'awaiting'       => $awaiting,
            'riders'         => User::whereIn('id', $awaiting->keys())->get()->keyBy('id'),
            'refundsToSend'  => ReturnRequest::with('order', 'buyer')->where('status', ReturnRequest::RESOLVED)
                ->whereNull('refund_released_at')->whereNull('refunded_at')->where('resolution_amount', '>', 0)->get(),
            'refundsOut'     => ReturnRequest::with('order', 'refundCourier')->whereNotNull('refund_released_at')->whereNull('refunded_at')->get(),
            'couriers'       => User::where('role', 'courier')->where('status', 'approved')->orderBy('last_name')->get(),
            'riderCash'      => $ledger->balancesByUser(Ledger::RIDER_CASH),
        ]);
    }

    public function remit(Request $request, User $courier, CodPayments $cod)
    {
        abort_unless($courier->role === 'courier', 404);
        $data = $request->validate(['order_ids' => 'required|array|min:1', 'order_ids.*' => 'integer']);
        $cents = $cod->confirmRemittance($courier, $data['order_ids'], $request->user());
        return back()->with('success', 'Confirmed ' . Money::format($cents) . " handed in by {$courier->full_name}.");
    }

    public function releaseRefund(Request $request, ReturnRequest $returnRequest, ReturnWorkflow $workflow)
    {
        $data = $request->validate(['courier_id' => 'required|integer']);
        $workflow->releaseRefund($returnRequest, $request->user(), User::findOrFail($data['courier_id']));
        return back()->with('success', "Refund cash for return #{$returnRequest->id} given to the rider.");
    }

    public function cancelRefund(Request $request, ReturnRequest $returnRequest, ReturnWorkflow $workflow)
    {
        $data = $request->validate(['reason' => 'required|string|max:300']);
        $workflow->cancelRelease($returnRequest, $request->user(), $data['reason']);
        return back()->with('success', "Refund cash for return #{$returnRequest->id} recorded as brought back.");
    }
}
