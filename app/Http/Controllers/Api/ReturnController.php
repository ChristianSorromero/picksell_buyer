<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ReturnRequest;
use App\Services\ReturnWorkflow;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;

/** Buyer steps in a return case: answer admin's questions, accept or decline the seller's proposal. */
class ReturnController extends Controller
{
    public function __construct(private ReturnWorkflow $workflow) {}

    /** POST /buyer/returns/{id}/reply — answers admin's request for more information. */
    public function reply(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate([
            'details'    => 'required|string|max:2000',
            'evidence'   => 'nullable|array|max:4',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);
        $this->ensureOwner($request, $returnRequest);
        $paths = collect($request->file('evidence', []))->map(fn ($f) => $f->store('uploads/returns', 'local'))->all();
        $this->workflow->reply($returnRequest, $request->user(), $data['details'], $paths);

        return $this->respond($returnRequest, 'Thanks — Picksell will review your reply.');
    }

    /** POST /buyer/returns/{id}/accept — agrees to the seller's proposed resolution. */
    public function accept(Request $request, ReturnRequest $returnRequest)
    {
        $this->ensureOwner($request, $returnRequest);
        $this->workflow->accept($returnRequest, $request->user());

        return $this->respond($returnRequest, 'Resolution accepted.');
    }

    /** POST /buyer/returns/{id}/decline — sends the case to Picksell for a final decision. */
    public function decline(Request $request, ReturnRequest $returnRequest)
    {
        $data = $request->validate(['reason' => 'required|string|max:1000']);
        $this->ensureOwner($request, $returnRequest);
        $this->workflow->decline($returnRequest, $request->user(), $data['reason']);

        return $this->respond($returnRequest, 'Sent to Picksell for a final decision.');
    }

    private function ensureOwner(Request $request, ReturnRequest $returnRequest): void
    {
        abort_if($returnRequest->buyer_id !== $request->user()->id, 404, 'Return request not found.');
    }

    private function respond(ReturnRequest $returnRequest, string $message)
    {
        return response()->json(['message' => $message, 'return_request' => BuyerPresenter::returnRequest($returnRequest->fresh())]);
    }
}
