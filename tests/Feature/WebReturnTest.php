<?php

namespace Tests\Feature;

use App\Models\ReturnRequest;
use App\Services\ReturnWorkflow;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** Buyers who use the website can open and follow a return case, under the app's rules. */
class WebReturnTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    private function deliveredOrder(int $quantity = 2)
    {
        $order = $this->outForDelivery($this->placeOrder($quantity));
        $this->deliver($order)->assertSessionHasNoErrors();
        return $order->fresh();
    }

    public function test_a_buyer_requests_a_return_on_the_website(): void
    {
        $order = $this->deliveredOrder();
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertOk()->assertSee('Request a return or refund');

        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", [
            'quantity' => 1, 'reason' => 'Item not as described', 'details' => 'Colour is different from the photos.',
        ])->assertSessionHasNoErrors();

        $r = ReturnRequest::sole();
        $this->assertSame(ReturnRequest::REQUESTED, $r->status);
        $this->assertSame('cash', $r->refund_to);
        $this->assertSame(30000, \App\Support\Money::cents($r->refund_amount)); // one of two ₱300 items
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertOk()
            ->assertSee("Return #{$r->id}")->assertSee('Waiting for Picksell review')->assertDontSee('Request a return or refund');

        // One case per order.
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Wrong item received'])
            ->assertSessionHasErrors('reason');
        $this->assertSame(1, ReturnRequest::count());
    }

    public function test_the_same_windows_and_ownership_rules_apply_as_in_the_app(): void
    {
        // Not delivered yet.
        $pending = $this->placeOrder();
        $this->actingAs($this->buyer)->post("/buyer/orders/{$pending->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])
            ->assertSessionHasErrors('reason');

        $order = $this->deliveredOrder();
        // Another buyer's order.
        $stranger = $this->makeUser('buyer', 'other@test.ph', ['email_verified_at' => now()]);
        $this->actingAs($stranger)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])->assertNotFound();
        // More items than were ordered.
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 3, 'reason' => 'Changed my mind'])
            ->assertSessionHasErrors('quantity');

        // After the change-of-mind window, only defect claims are accepted.
        $this->travel((int) config('picksell.return_window_days') + 1)->days();
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])
            ->assertSessionHasErrors('reason');
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Damaged or defective item'])
            ->assertSessionHasNoErrors();
        $this->assertSame(0, ReturnRequest::where('buyer_id', $stranger->id)->count());
        $this->assertSame(1, ReturnRequest::count());
    }

    public function test_the_buyer_answers_questions_and_decides_on_proposals(): void
    {
        $order = $this->deliveredOrder();
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Item not as described']);
        $r = ReturnRequest::sole();
        $workflow = app(ReturnWorkflow::class);

        $workflow->requestInfo($r, $this->admin, 'Please describe the difference.');
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertSee('Picksell asks: Please describe the difference.');
        $this->actingAs($this->buyer)->post("/buyer/returns/{$r->id}/reply", ['details' => 'It is blue, not red.'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::REQUESTED, $r->fresh()->status);

        $workflow->approve($r->fresh(), $this->admin, null);
        $workflow->propose($r->fresh(), $this->seller, 'partial_refund', '100.00', 'Sorry about the colour.');
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertSee('The seller proposes')->assertSee('₱100.00');

        // Only the buyer who owns the case can decide.
        $stranger = $this->makeUser('buyer', 'other@test.ph', ['email_verified_at' => now()]);
        $this->actingAs($stranger)->post("/buyer/returns/{$r->id}/accept")->assertNotFound();

        $this->actingAs($this->buyer)->post("/buyer/returns/{$r->id}/decline", ['reason' => 'I would like a full refund.'])->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::ESCALATED, $r->fresh()->status);
        // Nothing left to decide once escalated.
        $this->actingAs($this->buyer)->post("/buyer/returns/{$r->id}/accept")->assertStatus(422);
    }

    public function test_accepting_a_proposal_resolves_the_case(): void
    {
        $order = $this->deliveredOrder();
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Item not as described']);
        $r = ReturnRequest::sole();
        app(ReturnWorkflow::class)->approve($r, $this->admin, null);
        app(ReturnWorkflow::class)->propose($r->fresh(), $this->seller, 'partial_refund', '100.00', null);

        $this->actingAs($this->buyer)->post("/buyer/returns/{$r->id}/accept")->assertSessionHasNoErrors();
        $this->assertSame(ReturnRequest::RESOLVED, $r->fresh()->status);
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertSee('Agreed refund ₱100.00');
    }
}
