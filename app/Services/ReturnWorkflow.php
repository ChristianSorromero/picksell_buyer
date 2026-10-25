<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\LedgerTransaction;
use App\Models\Order;
use App\Models\ProductVariation;
use App\Models\ReturnRequest as R;
use App\Models\User;
use App\Support\Money;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * The return/refund case, admin first:
 *
 *   requested ──admin──▶ info_requested ──buyer replies──▶ requested
 *       │                     └──admin rejects──▶ rejected
 *       ├──admin rejects──▶ rejected
 *       └──admin approves──▶ with_seller ──seller proposes──▶ proposed ──buyer accepts──▶ resolved
 *                                 └──seller declines──┐            └──buyer declines──┐
 *                                                     ▼                               ▼
 *                                                 escalated ──admin decides──▶ resolved | rejected
 *
 *   resolved: a refund is paid in cash by a rider (sorting center releases the
 *   cash, the rider hands it over and collects the item when it must come
 *   back), the seller confirms the returned item and decides on restocking,
 *   or sends a replacement. When every step is done the case is completed.
 */
class ReturnWorkflow
{
    public function __construct(private Ledger $ledger) {}

    // ── Buyer ────────────────────────────────────────────────────────────

    public function open(Order $order, User $buyer, array $data, array $evidencePaths): R
    {
        return DB::transaction(function () use ($order, $buyer, $data, $evidencePaths) {
            $requested = BigDecimal::of(Money::cents($order->amount) * (int) $data['quantity'])
                ->dividedBy(max(1, (int) $order->quantity), 0, RoundingMode::HalfUp)->toInt();
            $return = R::create([
                'order_id'       => $order->id,
                'buyer_id'       => $buyer->id,
                'quantity'       => $data['quantity'],
                'reason'         => $data['reason'],
                'details'        => $data['details'] ?? null,
                'evidence_paths' => $evidencePaths ?: null,
                // What the buyer is asking for; the agreed amount is set on resolution.
                'refund_amount'  => Money::pesos($requested),
                'refund_to'      => 'cash',
                'status'         => R::REQUESTED,
            ]);
            AuditLog::record($return, 'requested', null, R::REQUESTED, $data['reason'], null, $buyer);
            $order->recordEvent('return_requested', 'You requested a return for ' . $data['quantity'] . ' item(s).');
            $this->notifyAdmins("Return request #{$return->id} for order {$order->order_number} is waiting for review.");

            return $return;
        });
    }

    public function reply(R $r, User $buyer, string $details, array $evidencePaths): void
    {
        $this->ensureBuyer($r, $buyer);
        $this->move($r, [R::INFO_REQUESTED], R::REQUESTED, $buyer, 'buyer_replied', fn (R $r) => [
            'details'        => trim(($r->details ? $r->details . "\n\n" : '') . 'Reply: ' . $details),
            'evidence_paths' => array_slice([...($r->evidence_paths ?? []), ...$evidencePaths], 0, 8) ?: null,
        ], $details);
        $this->notifyAdmins("The buyer replied on return request #{$r->id}.");
    }

    public function accept(R $r, User $buyer): void
    {
        $this->ensureBuyer($r, $buyer);
        $this->move($r, [R::PROPOSED], R::RESOLVED, $buyer, 'buyer_accepted',
            ['resolved_at' => now(), 'processing_at' => now()], null, null, fn (R $r) => $r->resolutionCents());
        $this->completeIfDone($r, $buyer);
    }

    public function decline(R $r, User $buyer, string $reason): void
    {
        $this->ensureBuyer($r, $buyer);
        $this->move($r, [R::PROPOSED], R::ESCALATED, $buyer, 'buyer_declined', ['escalated_at' => now()], $reason);
        $this->notifyAdmins("Return request #{$r->id} needs a final decision: the buyer declined the seller's proposal.");
    }

    // ── Admin ────────────────────────────────────────────────────────────

    public function requestInfo(R $r, User $admin, string $question): void
    {
        $this->move($r, [R::REQUESTED], R::INFO_REQUESTED, $admin, 'info_requested',
            ['info_request' => $question, 'reviewed_at' => now()], $question);
    }

    public function approve(R $r, User $admin, ?string $note): void
    {
        $this->move($r, [R::REQUESTED], R::WITH_SELLER, $admin, 'approved_for_seller',
            ['admin_approved_at' => now(), 'reviewed_at' => now()], $note);
    }

    public function reject(R $r, User $admin, string $reason): void
    {
        $this->move($r, [R::REQUESTED, R::INFO_REQUESTED, R::ESCALATED], R::REJECTED, $admin, 'rejected',
            ['rejected_at' => now(), 'resolution_note' => $reason], $reason);
    }

    /** Final decision on an escalated case. */
    public function decide(R $r, User $admin, string $type, ?string $amountPesos, string $note): void
    {
        [$type, $cents, $requiresReturn] = $this->resolution($r, $type, $amountPesos);
        $this->move($r, [R::ESCALATED], R::RESOLVED, $admin, 'admin_decided', [
            'resolution_type' => $type, 'resolution_amount' => Money::pesos($cents), 'requires_item_return' => $requiresReturn,
            'resolution_note' => $note, 'resolved_at' => now(), 'processing_at' => now(),
        ], $note, $cents);
        $this->completeIfDone($r, $admin);
    }

    // ── Seller ───────────────────────────────────────────────────────────

    public function propose(R $r, User $seller, string $type, ?string $amountPesos, ?string $note): void
    {
        $this->ensureSeller($r, $seller);
        [$type, $cents, $requiresReturn] = $this->resolution($r, $type, $amountPesos);
        $this->move($r, [R::WITH_SELLER], R::PROPOSED, $seller, 'seller_proposed', [
            'resolution_type' => $type, 'resolution_amount' => Money::pesos($cents), 'requires_item_return' => $requiresReturn,
            'seller_note' => $note, 'proposed_at' => now(),
        ], $note, $cents);
    }

    public function sellerDecline(R $r, User $seller, string $note): void
    {
        $this->ensureSeller($r, $seller);
        $this->move($r, [R::WITH_SELLER], R::ESCALATED, $seller, 'seller_declined',
            ['seller_note' => $note, 'escalated_at' => now()], $note);
        $this->notifyAdmins("Return request #{$r->id} needs a final decision: the seller declined it.");
    }

    public function confirmItemReceived(R $r, User $seller, bool $restock): void
    {
        $this->ensureSeller($r, $seller);
        DB::transaction(function () use ($r, $seller, $restock) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            abort_unless($r->needsItemReceipt(), 422, 'This return is not waiting for the item to come back.');
            // A refunded return comes back with the rider; a replacement return is shipped by the buyer.
            abort_if($r->resolution_type !== 'replacement' && !$r->item_collected_at, 422, 'The rider has not collected the item yet.');

            $r->update(['item_received_at' => now(), 'restocked' => $restock]);
            if ($restock) {
                // Only after the seller has the item and judged it sellable.
                $order = $r->order;
                $order->product?->increment('stock', $r->quantity);
                if ($order->variation_ids) ProductVariation::whereIn('id', $order->variation_ids)->increment('stock', $r->quantity);
            }
            AuditLog::record($r, $restock ? 'item_received_restocked' : 'item_received_not_restocked', $r->status, $r->status, null, null, $seller);
        });
        $this->completeIfDone($r->fresh(), $seller);
    }

    public function markReplacementSent(R $r, User $seller, ?string $note): void
    {
        $this->ensureSeller($r, $seller);
        DB::transaction(function () use ($r, $seller, $note) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            abort_unless($r->status === R::RESOLVED && $r->resolution_type === 'replacement' && !$r->replacement_sent_at, 422,
                'This return is not waiting for a replacement.');
            $r->update(['replacement_sent_at' => now()]);
            AuditLog::record($r, 'replacement_sent', $r->status, $r->status, $note, null, $seller);
        });
        $this->completeIfDone($r->fresh(), $seller);
    }

    // ── Refund cash: sorting center → rider → buyer ──────────────────────

    /** Sorting-center staff or admin hands the refund cash to a rider to deliver. */
    public function releaseRefund(R $r, User $staff, User $courier): void
    {
        abort_unless($courier->role === 'courier' && $courier->isApproved(), 422, 'Choose an approved rider.');
        DB::transaction(function () use ($r, $staff, $courier) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            $order = Order::lockForUpdate()->findOrFail($r->order_id);
            abort_unless($r->needsRefundHandover(), 422, 'This return has no refund waiting to be paid.');
            abort_if($r->refund_released_at, 422, 'The refund cash was already given to a rider.');
            abort_unless($order->payment_status === 'paid', 422, 'The buyer’s cash for this order has not been handed in yet, so it can’t be refunded.');

            $cents = $r->resolutionCents();
            $n = LedgerTransaction::where('return_request_id', $r->id)->where('type', 'refund_released')->count() + 1;
            $this->ledger->post('refund_released', "refund_released:return:{$r->id}:{$n}", [
                [Ledger::RIDER_CASH, $courier->id, $cents, $order->id],
                [Ledger::PLATFORM_CASH, null, -$cents, $order->id],
            ], ['order_id' => $order->id, 'return_request_id' => $r->id], $staff, "Refund cash for return #{$r->id} given to {$courier->full_name}");

            $r->update(['refund_courier_id' => $courier->id, 'refund_released_at' => now()]);
            AuditLog::record($r, 'refund_released', $r->status, $r->status, "Given to {$courier->full_name}", $cents, $staff);
        });
    }

    /** The rider brings undelivered refund cash back; it can be released again later. */
    public function cancelRelease(R $r, User $staff, string $reason): void
    {
        DB::transaction(function () use ($r, $staff, $reason) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            abort_unless($r->refund_released_at && !$r->refunded_at, 422, 'There is no outstanding refund cash with a rider.');

            $cents = $r->resolutionCents();
            $n = LedgerTransaction::where('return_request_id', $r->id)->where('type', 'refund_released')->count();
            $this->ledger->post('refund_release_reversed', "refund_release_reversed:return:{$r->id}:{$n}", [
                [Ledger::PLATFORM_CASH, null, $cents, $r->order_id],
                [Ledger::RIDER_CASH, $r->refund_courier_id, -$cents, $r->order_id],
            ], ['order_id' => $r->order_id, 'return_request_id' => $r->id], $staff, "Refund cash for return #{$r->id} brought back: {$reason}");

            $r->update(['refund_courier_id' => null, 'refund_released_at' => null]);
            AuditLog::record($r, 'refund_release_reversed', $r->status, $r->status, $reason, $cents, $staff);
        });
    }

    /** The rider hands the refund to the buyer (and collects the item when it must come back). */
    public function handOverRefund(R $r, User $courier, string $amountPesos, bool $itemCollected): void
    {
        DB::transaction(function () use ($r, $courier, $amountPesos, $itemCollected) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            $order = Order::lockForUpdate()->findOrFail($r->order_id);
            abort_if($r->refund_courier_id !== $courier->id, 403);
            abort_unless($r->needsRefundHandover() && $r->refund_released_at, 422, 'This refund is not waiting to be handed over.');

            $cents = $r->resolutionCents();
            abort_if(Money::cents($amountPesos) !== $cents, 422, 'Hand over exactly ' . Money::format($cents) . ' to the buyer.');
            abort_if($r->requires_item_return && !$itemCollected, 422, 'Collect the returned item from the buyer before handing over the refund.');

            $this->ledger->post('refund_paid', "refund_paid:return:{$r->id}", [
                [Ledger::ORDER_FUNDS, null, $cents, $order->id],
                [Ledger::RIDER_CASH, $courier->id, -$cents, $order->id],
            ], ['order_id' => $order->id, 'return_request_id' => $r->id], $courier, "Refund for return #{$r->id} handed to the buyer");

            $r->update(['refunded_at' => now()] + ($r->requires_item_return ? ['item_collected_at' => now()] : []));
            $order->update(['payment_status' => $cents >= $order->totalCents() ? 'refunded' : 'partially_refunded']);
            AuditLog::record($r, 'refund_handed_over', $r->status, $r->status, null, $cents, $courier);
            AuditLog::record($order, 'refunded', 'paid', $order->payment_status, "Return #{$r->id}", $cents, $courier);
            $order->recordEvent('refunded', Money::format($cents) . ' refunded to you in cash.');
        });
        $this->completeIfDone($r->fresh(), $courier);
    }

    // ── Rules ────────────────────────────────────────────────────────────

    /** The most that can be refunded: what the buyer paid for the order. */
    public function maxRefundCents(R $r): int
    {
        return $r->order->totalCents();
    }

    /** @return array{0: string, 1: int, 2: bool} type, centavos, item must come back */
    private function resolution(R $r, string $type, ?string $amountPesos): array
    {
        if (!isset(R::RESOLUTIONS[$type])) {
            throw ValidationException::withMessages(['resolution_type' => 'Choose a valid resolution.']);
        }
        [, $requiresReturn, $rule] = R::RESOLUTIONS[$type];
        $max = $this->maxRefundCents($r);
        $cents = Money::cents($amountPesos);

        $error = match ($rule) {
            'none'      => null,
            'max'       => null,
            'up_to_max' => $cents <= 0 || $cents > $max ? 'Enter a refund between ₱0.01 and ' . Money::format($max) . '.' : null,
            'below_max' => $cents <= 0 || $cents >= $max ? 'A partial refund must be more than ₱0.00 and less than ' . Money::format($max) . '.' : null,
        };
        if ($error) throw ValidationException::withMessages(['resolution_amount' => $error]);

        $cents = match ($rule) { 'none' => 0, 'max' => $max, default => $cents };
        return [$type, $cents, $requiresReturn];
    }

    /**
     * Moves the case if it is still in one of [$from]; refuses otherwise so
     * a stale page or a repeated click can't apply a step twice.
     */
    private function move(R $r, array $from, string $to, User $actor, string $action, array|\Closure $attrs, ?string $note = null, ?int $cents = null, ?\Closure $amount = null): void
    {
        DB::transaction(function () use ($r, $from, $to, $actor, $action, $attrs, $note, $cents, $amount) {
            $fresh = R::lockForUpdate()->findOrFail($r->id);
            abort_unless(in_array($fresh->status, $from, true), 422, 'This return request is no longer at that step. Refresh the page.');
            $previous = $fresh->status;
            $fresh->update(['status' => $to] + (is_array($attrs) ? $attrs : $attrs($fresh)));
            AuditLog::record($fresh, $action, $previous, $to, $note, $cents ?? $amount?->__invoke($fresh), $actor);
            $r->setRawAttributes($fresh->getAttributes(), true);
        });
    }

    private function completeIfDone(R $r, User $actor): void
    {
        DB::transaction(function () use ($r, $actor) {
            $r = R::lockForUpdate()->findOrFail($r->id);
            if ($r->status !== R::RESOLVED || !$r->stepsComplete()) return;
            $r->update(['status' => R::COMPLETED, 'completed_at' => now()]);
            AuditLog::record($r, 'completed', R::RESOLVED, R::COMPLETED, null, null, $actor);
        });
    }

    private function ensureBuyer(R $r, User $buyer): void
    {
        abort_if($r->buyer_id !== $buyer->id, 404);
    }

    private function ensureSeller(R $r, User $seller): void
    {
        abort_if($r->order->seller_id !== $seller->id, 403);
    }

    private function notifyAdmins(string $message): void
    {
        User::where('role', 'admin')->where('status', 'approved')->each(fn (User $admin) => $admin->notifications()->create([
            'id'   => (string) Str::uuid(),
            'type' => 'App\Notifications\AdminActivity',
            'data' => json_encode(['message' => $message]),
        ]));
    }
}
