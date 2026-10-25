<?php

namespace App\Http\Controllers;

use App\Models\ReturnRequest;
use App\Services\ReturnWorkflow;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/** Admin-first review of return/refund requests, and final decisions on escalations. */
class AdminReturnController extends Controller
{
    public function __construct(private ReturnWorkflow $workflow) {}

    public function index(Request $request)
    {
        $status = $request->get('status', 'needs_admin');
        $returns = ReturnRequest::with('order.seller', 'buyer')
            ->when($status === 'needs_admin', fn ($q) => $q->whereIn('status', [ReturnRequest::REQUESTED, ReturnRequest::ESCALATED]))
            ->when(!in_array($status, ['needs_admin', 'all'], true), fn ($q) => $q->where('status', $status))
            ->latest()->paginate(20)->withQueryString();

        return view('admin.returns', compact('returns', 'status'));
    }

    public function show(ReturnRequest $returnRequest)
    {
        $returnRequest->load('order.seller', 'order.buyer', 'order.courier', 'order.events', 'auditLogs.actor', 'refundCourier');

        return view('admin.return-detail', [
            'r'         => $returnRequest,
            'maxRefund' => $this->workflow->maxRefundCents($returnRequest),
        ]);
    }

    public function requestInfo(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['question' => 'required|string|max:1000']);
        $this->workflow->requestInfo($returnRequest, $request->user(), $data['question']);
        return back()->with('success', 'The buyer was asked for more information.');
    }

    public function approve(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['note' => 'nullable|string|max:1000', 'liable_party' => 'nullable|string']);
        $this->workflow->approve($returnRequest, $request->user(), $data['note'] ?? null, $data['liable_party'] ?? null);
        return back()->with('success', 'Approved and sent to the seller for resolution.');
    }

    public function liability(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['liable_party' => 'required|string', 'note' => 'required|string|max:1000']);
        $this->workflow->setLiability($returnRequest, $request->user(), $data['liable_party'], $data['note']);
        return back()->with('success', 'Responsibility recorded.');
    }

    public function expedite(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['reason' => 'required|string|max:1000']);
        $this->workflow->expedite($returnRequest, $request->user(), $data['reason']);
        return back()->with('success', 'Refund expedited: the rider will pay it when collecting the item.');
    }

    public function reject(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['reason' => 'required|string|max:1000']);
        $this->workflow->reject($returnRequest, $request->user(), $data['reason']);
        return back()->with('success', 'Return request rejected.');
    }

    public function decide(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate([
            'resolution_type'   => 'required|string',
            'resolution_amount' => 'nullable|numeric|min:0',
            'note'              => 'required|string|max:1000',
            'liable_party'      => 'nullable|string',
        ]);
        $this->workflow->decide($returnRequest, $request->user(), $data['resolution_type'], $data['resolution_amount'] ?? null, $data['note'], $data['liable_party'] ?? null);
        return back()->with('success', 'Final decision recorded.');
    }

    /** Evidence photos live on the private disk; only admins can open them. */
    public function evidence(ReturnRequest $returnRequest, int $index)
    {
        $path = $returnRequest->evidence_paths[$index] ?? null;
        abort_unless($path && Storage::disk('local')->exists($path), 404);
        return Storage::disk('local')->response($path);
    }
}
