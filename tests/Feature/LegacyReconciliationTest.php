<?php

namespace Tests\Feature;

use App\Models\LedgerTransaction;
use App\Models\Order;
use App\Models\ReturnRequest;
use App\Services\Ledger;
use App\Services\Settlements;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** Orders delivered before COD tracking: evidence-based backfill or a controlled unresolved state. */
class LegacyReconciliationTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    /** Mirrors PS-51351586: delivered under the old flow, never recorded as collected. */
    private function legacyOrder(): Order
    {
        $order = $this->placeOrder();
        $order->update(['status' => 'completed', 'tracking_status' => 'Delivered', 'delivered_at' => now()->subDays(5), 'courier_id' => $this->courier->id]);
        return $order->fresh();
    }

    public function test_only_admins_with_evidence_and_the_exact_total_can_backfill(): void
    {
        $order = $this->legacyOrder();
        $this->actingAs($this->admin)->get('/admin/finance')->assertOk()->assertSee($order->order_number)->assertSee('Delivered Before COD Tracking');

        $this->actingAs($this->logistics)->post("/admin/finance/orders/{$order->id}/backfill", ['amount' => '345.00', 'evidence' => 'x', 'reason' => 'x'])->assertForbidden();
        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/backfill", ['amount' => '345.00'])->assertSessionHasErrors(['evidence', 'reason']);
        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/backfill", ['amount' => '300.00', 'evidence' => 'Remittance sheet #44', 'reason' => 'Signed by rider and supervisor'])
            ->assertStatus(422); // must equal the order total
        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/backfill", [
            'amount' => '345.00', 'evidence' => 'Remittance sheet #44', 'reason' => 'Signed by rider and supervisor',
        ])->assertSessionHasNoErrors();

        $order->refresh();
        $this->assertSame('paid', $order->payment_status);
        $this->assertNull($order->paid_at);            // hand-in time unknown: not invented
        $this->assertNull($order->cod_collected_at);   // no date in the evidence
        $this->assertNotNull($order->payment_backfilled_at);
        $txn = LedgerTransaction::where('type', 'cod_backfill')->sole();
        $this->assertTrue($txn->details['historical']);
        $this->assertSame('Remittance sheet #44', $txn->details['evidence']);
        $this->assertSame(34500, app(Ledger::class)->balance(Ledger::PLATFORM_CASH));

        // Once only; and backfilled deliveries earn no rider pay.
        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/backfill", ['amount' => '345.00', 'evidence' => 'x', 'reason' => 'x'])->assertStatus(422);
        $this->assertSame(0, LedgerTransaction::where('type', 'rider_pay_accrued')->count());

        // It then settles normally after the window.
        $this->travel(3)->days();
        $this->assertSame(1, app(Settlements::class)->settleEligible());
    }

    public function test_unverifiable_orders_stay_out_of_refunds_and_settlement(): void
    {
        $order = $this->legacyOrder();
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Damaged or defective item'])->assertCreated();
        $this->useWebGuard();
        $r = ReturnRequest::sole();
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'full_refund']);
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept");
        $this->useWebGuard();

        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/unverifiable", ['note' => 'No remittance record found'])->assertSessionHasNoErrors();
        $this->assertSame('unverifiable', $order->fresh()->payment_review);

        // Refund blocked, nothing settles, nothing moves.
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);
        $this->assertStringContainsString('could not be verified', $r->fresh()->refundBlocker());
        $this->travel(10)->days();
        $this->assertSame(0, app(Settlements::class)->settleEligible());
        $this->assertSame(0, \App\Models\LedgerEntry::count());

        // Evidence found later: backfill clears the review, and the refund can proceed.
        $this->actingAs($this->admin)->post("/admin/finance/orders/{$order->id}/backfill", [
            'amount' => '345.00', 'evidence' => 'Bank deposit slip 0099', 'reason' => 'Found in branch records', 'collected_on' => now()->subDays(14)->toDateString(),
        ])->assertSessionHasNoErrors();
        $this->assertNull($order->fresh()->payment_review);
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
    }
}
