<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\ReturnRequest;
use App\Services\Ledger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** G09: admin reviews first, the seller resolves with the buyer, refunds go back in cash. */
class ReturnWorkflowTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    private function openReturn(Order $order, int $quantity = 1): ReturnRequest
    {
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => $quantity, 'reason' => 'Damaged or defective item', 'details' => 'Cracked handle'])
            ->assertCreated();
        $this->useWebGuard();
        return ReturnRequest::latest('id')->first();
    }

    private function returnJson(Order $order): array
    {
        $this->asBuyerApi();
        $json = $this->getJson("/api/buyer/orders/{$order->id}")->assertOk()->json('order.return_request');
        $this->useWebGuard();
        return $json;
    }

    public function test_return_and_refund_runs_from_request_to_completed_with_cash_and_restock(): void
    {
        $order = $this->paidOrder(2); // ₱645 paid
        $r = $this->openReturn($order);

        // Admin is notified; the seller can't see it until admin approves.
        $this->assertSame(1, $this->admin->notifications()->count());
        $this->actingAs($this->seller)->get("/seller/returns/{$r->id}")->assertNotFound();
        $this->actingAs($this->seller)->get('/seller/returns')->assertOk()->assertDontSee($order->order_number);

        // Admin asks for more information; buyer replies through the app.
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/request-info", ['question' => 'Photo of the crack?'])->assertSessionHasNoErrors();
        $this->assertSame('reply', $this->returnJson($order)['awaiting']);
        $this->assertSame('under_review', $this->returnJson($order)['status']);
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/reply", ['details' => 'Attached'])->assertOk()->assertJsonPath('return_request.stage', 'requested');
        $this->useWebGuard();

        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve", ['note' => 'Photos confirm damage'])->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->get("/seller/returns/{$r->id}")->assertOk();

        // Seller proposes; amounts above what was paid are refused.
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'return_and_refund', 'resolution_amount' => '645.01'])
            ->assertSessionHasErrors('resolution_amount');
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'return_and_refund', 'resolution_amount' => '300.00', 'note' => 'Refund for one mug'])
            ->assertSessionHasNoErrors();
        $json = $this->returnJson($order);
        $this->assertSame('decide', $json['awaiting']);
        $this->assertEquals(300, $json['proposal']['amount']);
        $this->assertTrue($json['proposal']['item_must_return']);

        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept")->assertOk()->assertJsonPath('return_request.status', 'processing');
        $this->postJson("/api/buyer/returns/{$r->id}/accept")->assertStatus(422);
        $this->useWebGuard();

        // Default timing: the item is picked up and inspected before any refund goes out.
        $r->refresh();
        $this->assertSame('after_inspection', $r->refund_timing);
        $this->assertSame('seller', $r->liable_party);       // presumed from "Damaged or defective item"
        $this->assertSame('seller', $r->refund_funded_by);
        $this->assertSame('cash', $r->refund_to);
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])
            ->assertStatus(422);
        $this->assertSame('paid', $order->fresh()->payment_status);

        // Pickup: no cash changes hands; only the assigned rider can record it.
        $this->actingAs($this->logistics)->post("/logistics/returns/{$r->id}/pickup", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->otherCourier)->post("/courier/returns/{$r->id}/picked-up")->assertForbidden();
        $this->actingAs($this->courier)->get('/courier/orders')->assertOk()->assertSee('Items to Pick Up');
        $this->actingAs($this->courier)->post("/courier/returns/{$r->id}/picked-up")->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/returns/{$r->id}/picked-up")->assertStatus(422);
        $this->assertSame(0, app(Ledger::class)->balance(Ledger::RIDER_CASH, $this->courier->id));

        // Seller inspects; stock goes back only now, and only because it passed and was restocked.
        $this->assertSame(8, $this->mug->fresh()->stock);
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 1, 'restock' => 1])->assertSessionHasNoErrors();
        $this->assertSame(9, $this->mug->fresh()->stock);

        // Now the refund cash can go out, once.
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->assertSame(30000, app(Ledger::class)->balance(Ledger::RIDER_CASH, $this->courier->id));

        $this->actingAs($this->otherCourier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00'])->assertForbidden();
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '250.00'])->assertStatus(422);
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00'])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00'])->assertStatus(422);

        $this->assertSame('partially_refunded', $order->fresh()->payment_status);
        $this->assertSame(0, app(Ledger::class)->balance(Ledger::RIDER_CASH, $this->courier->id));

        $r->refresh();
        $this->assertSame(ReturnRequest::COMPLETED, $r->status);
        $this->assertSame('refunded', $this->returnJson($order)['status']);
        $this->assertSame(
            ['requested', 'info_requested', 'buyer_replied', 'approved_for_seller', 'seller_proposed', 'buyer_accepted',
             'pickup_assigned', 'item_picked_up', 'item_received_restocked', 'refund_released', 'refund_handed_over', 'completed'],
            $r->auditLogs()->reorder('id')->pluck('action')->all(),
        );
        $this->actingAs($this->admin)->get("/admin/returns/{$r->id}")->assertOk()->assertSee('refund handed over');
    }

    /** Resolves a return-and-refund case for ₱300, ready for pickup. */
    private function resolvedReturn(Order $order, string $type = 'return_and_refund', ?string $amount = '300.00'): ReturnRequest
    {
        $r = $this->openReturn($order);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve")->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => $type, 'resolution_amount' => $amount])->assertSessionHasNoErrors();
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept")->assertOk();
        $this->useWebGuard();
        return $r->fresh();
    }

    public function test_admin_can_expedite_a_verified_claim_so_the_rider_refunds_on_pickup(): void
    {
        $order = $this->paidOrder();
        $r = $this->resolvedReturn($order);

        $this->actingAs($this->seller)->post("/admin/returns/{$r->id}/expedite", ['reason' => 'x'])->assertForbidden();
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/expedite", ['reason' => 'Photos clearly show a shattered mug'])->assertSessionHasNoErrors();
        $r->refresh();
        $this->assertSame('on_pickup', $r->refund_timing);
        $this->assertSame($this->admin->id, $r->expedited_by);

        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        // Same visit: the rider must collect the item before handing over the cash.
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00'])->assertStatus(422);
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00', 'item_collected' => 1])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::RESOLVED, $r->fresh()->status); // seller still has to confirm receipt

        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 1, 'restock' => 0])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::COMPLETED, $r->fresh()->status);
        $this->assertSame(1, $r->auditLogs()->where('action', 'refund_expedited')->count());
    }

    public function test_a_failed_inspection_goes_to_admin_and_nothing_is_restocked_or_refunded(): void
    {
        $order = $this->paidOrder();
        $r = $this->resolvedReturn($order);
        $this->actingAs($this->logistics)->post("/logistics/returns/{$r->id}/pickup", ['courier_id' => $this->courier->id]);
        $this->actingAs($this->courier)->post("/courier/returns/{$r->id}/picked-up");

        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 0, 'restock' => 1])
            ->assertSessionHasErrors('inspection_note');
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 0, 'restock' => 1, 'inspection_note' => 'Water damage, not a defect'])
            ->assertSessionHasNoErrors();

        $r->refresh();
        $this->assertSame(ReturnRequest::ESCALATED, $r->status);
        $this->assertFalse($r->inspection_passed);
        $this->assertFalse($r->restocked);
        $this->assertSame(9, $this->mug->fresh()->stock);
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);

        // Admin reviews and decides; responsibility moves to the buyer, so no refund.
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/reject", ['reason' => 'Damage caused by the buyer'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::REJECTED, $r->fresh()->status);
        $this->assertSame('paid', $order->fresh()->payment_status);
    }

    public function test_courier_damage_is_funded_by_picksell_and_never_charged_to_the_seller_or_rider(): void
    {
        $order = $this->paidOrder();
        $r = $this->resolvedReturn($order, 'full_refund', null);
        $this->assertSame('no_return', $r->refund_timing);

        // Undetermined responsibility blocks the cash.
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/liability", ['liable_party' => 'undetermined', 'note' => 'Checking with logistics'])->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);

        $this->actingAs($this->seller)->post("/admin/returns/{$r->id}/liability", ['liable_party' => 'seller', 'note' => 'x'])->assertForbidden();
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/liability", ['liable_party' => 'logistics', 'note' => 'Crushed box, courier report #12'])->assertSessionHasNoErrors();
        $this->assertSame('platform', $r->fresh()->refund_funded_by);

        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '345.00'])->assertSessionHasNoErrors();

        $this->travel(8)->days();
        app(\App\Services\Settlements::class)->settleEligible();
        $ledger = app(Ledger::class);
        // Seller keeps ₱300 − 10% commission; Picksell bears the ₱345 refund.
        $this->assertSame(27000, -$ledger->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(0, $ledger->balance(Ledger::RIDER_CASH, $this->courier->id));
        $this->assertSame(0, -$ledger->balance(Ledger::RIDER_PAYABLE, $this->courier->id));
        $this->assertSame(0, (int) \App\Models\LedgerEntry::sum('amount_cents'));
    }

    public function test_defect_claims_have_a_longer_window_than_change_of_mind(): void
    {
        $order = $this->paidOrder();
        $this->travel(20)->days();
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])->assertStatus(422);
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Damaged or defective item'])->assertCreated();
    }

    public function test_a_defect_refund_after_settlement_is_booked_as_an_adjustment(): void
    {
        $order = $this->paidOrder();
        $this->travel(8)->days();
        app(\App\Services\Settlements::class)->settleEligible();
        $this->assertSame(27000, -app(Ledger::class)->balance(Ledger::SELLER_PAYABLE, $this->seller->id));

        $r = $this->resolvedReturn($order, 'partial_refund', '100.00');
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '100.00'])->assertSessionHasNoErrors();

        // Seller-funded ₱100: seller loses ₱90, Picksell gives back its ₱10 commission.
        $ledger = app(Ledger::class);
        $this->assertSame(18000, -$ledger->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(0, $ledger->balance(Ledger::ORDER_FUNDS, null, $order->id));
        $this->assertSame(0, (int) \App\Models\LedgerEntry::sum('amount_cents'));
        $this->assertTrue(\App\Models\LedgerTransaction::where('type', 'late_refund_adjustment')->exists());
        $this->assertSame(1, \App\Models\LedgerTransaction::where('type', 'order_settlement')->count()); // settlement untouched
    }

    public function test_disagreement_goes_to_admin_for_a_final_decision(): void
    {
        $order = $this->paidOrder();
        $r = $this->openReturn($order);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve")->assertSessionHasNoErrors();

        // Partial refund must be below the total; buyer declines → escalated.
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'partial_refund', 'resolution_amount' => '345.00'])
            ->assertSessionHasErrors('resolution_amount');
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'partial_refund', 'resolution_amount' => '50.00']);
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/decline", ['reason' => 'Too low'])->assertOk()->assertJsonPath('return_request.stage', 'escalated');
        $this->useWebGuard();

        // Only admin decides; the seller can't act on an escalated case.
        $this->actingAs($this->seller)->post("/admin/returns/{$r->id}/decide", ['resolution_type' => 'full_refund', 'note' => 'x'])->assertForbidden();
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'full_refund'])->assertStatus(422);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/decide", ['resolution_type' => 'full_refund', 'note' => 'Item arrived broken'])->assertSessionHasNoErrors();

        $r->refresh();
        $this->assertSame(ReturnRequest::RESOLVED, $r->status);
        $this->assertSame(34500, $r->resolutionCents()); // full refund = everything paid
        $this->assertFalse($r->requires_item_return);

        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id]);
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '345.00'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::COMPLETED, $r->fresh()->status);
        $this->assertSame('refunded', $order->fresh()->payment_status);
        $this->assertSame(9, $this->mug->fresh()->stock); // the buyer keeps the item: nothing restocked
    }

    public function test_seller_decline_escalates_and_admin_can_reject(): void
    {
        $order = $this->paidOrder();
        $r = $this->openReturn($order);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/decline", ['note' => 'Damage was caused by misuse'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::ESCALATED, $r->fresh()->status);
        $this->assertSame(2, $this->admin->notifications()->count()); // new request + escalation

        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/reject", ['reason' => 'Misuse confirmed'])->assertSessionHasNoErrors();
        $json = $this->returnJson($order);
        $this->assertSame('rejected', $json['status']);
        $this->assertSame('Misuse confirmed', $json['resolution_note']);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve")->assertStatus(422);
    }

    public function test_replacement_needs_the_item_back_and_the_replacement_sent_and_moves_no_money(): void
    {
        $order = $this->paidOrder();
        $r = $this->openReturn($order);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'replacement'])->assertSessionHasNoErrors();
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept")->assertOk();
        $this->useWebGuard();

        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/replacement-sent", ['note' => 'WB-9'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::RESOLVED, $r->fresh()->status);
        // The old item comes back through a rider pickup before the seller can confirm it.
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 1, 'restock' => 0])->assertStatus(422);
        $this->actingAs($this->logistics)->post("/logistics/returns/{$r->id}/pickup", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/returns/{$r->id}/picked-up")->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 1, 'restock' => 0])->assertSessionHasNoErrors();

        $this->assertSame(ReturnRequest::COMPLETED, $r->fresh()->status);
        $this->assertSame('paid', $order->fresh()->payment_status);
        $this->assertSame(9, $this->mug->fresh()->stock); // not restocked
    }

    public function test_refund_cash_needs_the_buyers_cash_handed_in_and_can_be_brought_back(): void
    {
        $order = $this->outForDelivery($this->placeOrder());
        $this->deliver($order); // collected, not yet handed in
        $r = $this->openReturn($order);
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'full_refund']);
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept");
        $this->useWebGuard();

        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->remit([$order])->assertSessionHasNoErrors();

        // Released, brought back (buyer not home), released again to another rider.
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/cancel", ['reason' => 'Buyer not home'])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '345.00'])->assertForbidden();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->otherCourier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->otherCourier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '345.00'])->assertSessionHasNoErrors();

        $ledger = app(Ledger::class);
        $this->assertSame(0, $ledger->balance(Ledger::RIDER_CASH, $this->courier->id));
        $this->assertSame(0, $ledger->balance(Ledger::RIDER_CASH, $this->otherCourier->id));
        $this->assertSame(0, $ledger->balance(Ledger::PLATFORM_CASH));
        $this->assertSame(0, $ledger->balance(Ledger::ORDER_FUNDS, null, $order->id));
    }

    public function test_people_can_only_act_on_their_own_cases(): void
    {
        $order = $this->paidOrder();
        $r = $this->openReturn($order);
        $strangerBuyer = $this->makeUser('buyer', 'other-buyer@test.ph', ['email_verified_at' => now()]);
        $otherSeller = $this->makeUser('seller', 'other-seller@test.ph');
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");

        \Laravel\Sanctum\Sanctum::actingAs($strangerBuyer);
        $this->postJson("/api/buyer/returns/{$r->id}/decline", ['reason' => 'x'])->assertNotFound();
        $this->useWebGuard();
        $this->actingAs($otherSeller)->get("/seller/returns/{$r->id}")->assertNotFound();
        $this->actingAs($otherSeller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'full_refund'])->assertNotFound();
        $this->actingAs($this->seller)->get('/admin/returns')->assertForbidden();
        $this->actingAs($this->buyer)->get('/admin/finance')->assertForbidden();
        $this->actingAs($this->seller)->get("/admin/returns/{$r->id}/evidence/0")->assertForbidden();

        // One return per order, only within the return window.
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])->assertStatus(422);
    }
}
