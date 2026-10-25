<?php

namespace App\Http\Controllers;

use App\Models\LedgerEntry;
use App\Models\Payout;
use App\Models\ReturnRequest;
use App\Services\Ledger;
use App\Services\ReturnWorkflow;
use Illuminate\Http\Request;

/** Seller side of admin-approved returns, plus settlements and payouts. */
class SellerReturnController extends Controller
{
    public function __construct(private ReturnWorkflow $workflow) {}

    /** Admin-approved cases only: the seller never sees a request before review. */
    public function index(Request $request)
    {
        $returns = ReturnRequest::with('order', 'buyer')
            ->whereHas('order', fn ($q) => $q->where('seller_id', $request->user()->id))
            ->whereNotNull('admin_approved_at')
            ->latest()->paginate(15);

        return view('seller.returns', compact('returns'));
    }

    public function show(Request $request, ReturnRequest $returnRequest)
    {
        $this->authorizeSeller($request, $returnRequest);
        $returnRequest->load('order', 'buyer', 'auditLogs.actor');

        return view('seller.return-detail', ['r' => $returnRequest, 'maxRefund' => $this->workflow->maxRefundCents($returnRequest)]);
    }

    public function propose(Request $request, ReturnRequest $returnRequest)
    {
        $this->authorizeSeller($request, $returnRequest);
        $data = $request->validate([
            'resolution_type'   => 'required|string',
            'resolution_amount' => 'nullable|numeric|min:0',
            'note'              => 'nullable|string|max:1000',
        ]);
        $this->workflow->propose($returnRequest, $request->user(), $data['resolution_type'], $data['resolution_amount'] ?? null, $data['note'] ?? null);
        return back()->with('success', 'Your proposal was sent to the buyer.');
    }

    public function decline(Request $request, ReturnRequest $returnRequest)
    {
        $this->authorizeSeller($request, $returnRequest);
        $data = $request->validate(['note' => 'required|string|max:1000']);
        $this->workflow->sellerDecline($returnRequest, $request->user(), $data['note']);
        return back()->with('success', 'Sent to Picksell for a final decision.');
    }

    public function itemReceived(Request $request, ReturnRequest $returnRequest)
    {
        $this->authorizeSeller($request, $returnRequest);
        $data = $request->validate([
            'inspection_passed' => 'required|boolean',
            'restock'           => 'nullable|boolean',
            'inspection_note'   => 'required_if:inspection_passed,0|nullable|string|max:1000',
        ], ['inspection_note.required_if' => 'Describe what failed the inspection.']);
        $passed = (bool) $data['inspection_passed'];
        $this->workflow->confirmItemReceived($returnRequest, $request->user(), (bool) ($data['restock'] ?? false), $passed, $data['inspection_note'] ?? null);

        return back()->with('success', match (true) {
            !$passed                   => 'Inspection failure recorded and sent to Picksell for a decision.',
            (bool) ($data['restock'] ?? false) => 'Item received, inspected and put back in stock.',
            default                    => 'Item received and inspected (not restocked).',
        });
    }

    public function replacementSent(Request $request, ReturnRequest $returnRequest)
    {
        $this->authorizeSeller($request, $returnRequest);
        $data = $request->validate(['note' => 'nullable|string|max:500']);
        $this->workflow->markReplacementSent($returnRequest, $request->user(), $data['note'] ?? null);
        return back()->with('success', 'Replacement marked as sent.');
    }

    /** What the seller is owed per settled order, and their payouts. */
    public function payouts(Request $request, Ledger $ledger)
    {
        $seller = $request->user();
        // Amounts as recorded at settlement, not recomputed with today's rates.
        $settled = LedgerEntry::with('transaction.order', 'payoutItem.payout')->where('account', Ledger::SELLER_PAYABLE)
            ->where('user_id', $seller->id)->where('amount_cents', '<', 0)->latest('id')->paginate(20);

        return view('seller.payouts', [
            'owed'    => -$ledger->balance(Ledger::SELLER_PAYABLE, $seller->id),
            'settled' => $settled,
            'payouts' => Payout::where('payee_id', $seller->id)->latest()->get(),
        ]);
    }

    private function authorizeSeller(Request $request, ReturnRequest $returnRequest): void
    {
        abort_if($returnRequest->order->seller_id !== $request->user()->id || !$returnRequest->admin_approved_at, 404);
    }
}
