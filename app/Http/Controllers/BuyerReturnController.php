<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\ReturnRequest;
use App\Services\ReturnWorkflow;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Buyer return cases on the website: open one, answer admin's questions,
 * accept or decline the seller's proposal. Same rules as the app
 * (Api\OrderController::requestReturn, Api\ReturnController).
 */
class BuyerReturnController extends Controller
{
    public function __construct(private ReturnWorkflow $workflow) {}

    public function store(Request $request, Order $order)
    {
        abort_if($order->buyer_id !== $request->user()->id, 404);
        $data = $request->validate([
            'quantity'   => "required|integer|min:1|max:{$order->quantity}",
            'reason'     => ['required', Rule::in(ReturnRequest::REASONS)],
            'details'    => 'nullable|string|max:2000',
            'evidence'   => 'nullable|array|max:4',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);
        if ($refusal = ReturnRequest::refusalFor($order, $data['reason'])) {
            throw ValidationException::withMessages(['reason' => $refusal]);
        }

        $paths = collect($request->file('evidence', []))->map(fn ($f) => $f->store('uploads/returns', 'local'))->all();
        $this->workflow->open($order, $request->user(), $data, $paths);

        return back()->with('success', "Return requested for order {$order->order_number}. Picksell will review it first; refunds are paid in cash by a rider.");
    }

    public function reply(Request $request, ReturnRequest $returnRequest)
    {
        $this->ensureOwner($request, $returnRequest);
        $data = $request->validate([
            'details'    => 'required|string|max:2000',
            'evidence'   => 'nullable|array|max:4',
            'evidence.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);
        $paths = collect($request->file('evidence', []))->map(fn ($f) => $f->store('uploads/returns', 'local'))->all();
        $this->workflow->reply($returnRequest, $request->user(), $data['details'], $paths);

        return back()->with('success', 'Thanks — Picksell will review your reply.');
    }

    public function accept(Request $request, ReturnRequest $returnRequest)
    {
        $this->ensureOwner($request, $returnRequest);
        $this->workflow->accept($returnRequest, $request->user());

        return back()->with('success', 'Resolution accepted.');
    }

    public function decline(Request $request, ReturnRequest $returnRequest)
    {
        $this->ensureOwner($request, $returnRequest);
        $data = $request->validate(['reason' => 'required|string|max:1000']);
        $this->workflow->decline($returnRequest, $request->user(), $data['reason']);

        return back()->with('success', 'Sent to Picksell for a final decision.');
    }

    private function ensureOwner(Request $request, ReturnRequest $returnRequest): void
    {
        abort_if($returnRequest->buyer_id !== $request->user()->id, 404);
    }
}
