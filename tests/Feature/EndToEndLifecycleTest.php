<?php

namespace Tests\Feature;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Payout;
use App\Models\ReturnRequest;
use App\Services\Ledger;
use App\Support\LocalTime;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/**
 * One order through every role and every money step, using only the web
 * pages people use: website checkout → seller → sorting center → rider
 * (COD) → cash hand-in → website return → admin → seller → pickup →
 * inspection → refund cash → settlement → two-person payout.
 *
 * ₱300 × 2 + ₱45 shipping = ₱645 COD. One item is returned for a ₱300
 * refund funded by the seller (seller at fault). The seller is then owed
 * ₱300 − 10% commission = ₱270; Picksell keeps ₱30 + ₱45 shipping = ₱75.
 */
class EndToEndLifecycleTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    public function test_order_cod_return_refund_settlement_and_payout_end_to_end(): void
    {
        $this->buildMarketplace();
        $this->buyer->update(['province' => 'Metro Manila', 'municipality' => 'Quezon City', 'barangay' => 'Diliman', 'street' => 'Katipunan Ave', 'house_no' => '12']);
        $secondAdmin = $this->makeUser('admin', 'admin2@test.ph');
        config(['picksell.finance.payout_requires_second_admin' => true, 'picksell.finance.second_admin_threshold' => '0']);
        $ledger = app(Ledger::class);

        // Buyer: website checkout, cash on delivery.
        $item = CartItem::create(['cart_id' => Cart::create(['buyer_id' => $this->buyer->id])->id, 'product_id' => $this->mug->id, 'quantity' => 2]);
        $this->actingAs($this->buyer)->from('/buyer/cart')->post('/buyer/cart/checkout', [
            'item_ids' => [$item->id], 'payment_method' => 'cod', 'shipping_option' => 'standard',
        ])->assertRedirect('/buyer/orders')->assertSessionHas('success', 'Order placed! Total charged on delivery: ₱645.00.');
        $order = Order::sole();
        $this->assertSame(['unpaid', 64500, 8], [$order->payment_status, $order->totalCents(), $this->mug->fresh()->stock]);

        // Seller packs and hands over; sorting center scans and assigns a rider.
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/pack")->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->patch("/seller/orders/{$order->id}/handover", ['waybill_number' => 'WB-E2E'])->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/scan")->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->patch("/logistics/parcels/{$order->id}/assign", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();

        // Rider: a failed attempt, then delivery with exact cash and proof of delivery.
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/orders/{$order->id}/failed", ['reason' => config('picksell.delivery.failed_reasons')[0]])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '600.00', 'recipient_name' => 'Ana Reyes'])
            ->assertStatus(422); // short by the shipping fee
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '645.00', 'recipient_name' => 'Ana Reyes'])
            ->assertSessionHasNoErrors();
        $this->assertSame('collected', $order->fresh()->payment_status);
        $this->assertSame(64500, $ledger->balance(Ledger::RIDER_CASH, $this->courier->id));
        $this->assertSame(2, $order->attempts()->count());

        // Sorting center confirms the cash hand-in.
        $this->actingAs($this->logistics)->post("/logistics/cash/riders/{$this->courier->id}/remit", ['order_ids' => [$order->id]])->assertSessionHasNoErrors();
        $this->assertSame('paid', $order->fresh()->payment_status);
        $this->assertSame([0, 64500], [$ledger->balance(Ledger::RIDER_CASH, $this->courier->id), $ledger->balance(Ledger::PLATFORM_CASH)]);

        // Buyer: return one item on the website.
        $this->actingAs($this->buyer)->post("/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Item not as described', 'details' => 'Wrong colour'])
            ->assertSessionHasNoErrors();
        $r = ReturnRequest::sole();

        // Admin approves (seller at fault); seller proposes return-and-refund; buyer accepts on the website.
        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve", ['liable_party' => 'seller'])->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'return_and_refund', 'resolution_amount' => '300.00'])
            ->assertSessionHasNoErrors();
        $this->actingAs($this->buyer)->post("/buyer/returns/{$r->id}/accept")->assertSessionHasNoErrors();
        $r->refresh();
        $this->assertSame([ReturnRequest::RESOLVED, 'after_inspection', 'seller'], [$r->status, $r->refund_timing, $r->refund_funded_by]);

        // No refund cash before the item is back and inspected.
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertStatus(422);

        // Pickup → seller inspection → refund cash to the rider → handed to the buyer.
        $this->actingAs($this->logistics)->post("/logistics/returns/{$r->id}/pickup", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->post("/courier/returns/{$r->id}/picked-up")->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/item-received", ['inspection_passed' => 1, 'restock' => 1])->assertSessionHasNoErrors();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id])->assertSessionHasNoErrors();
        $this->assertSame(30000, $ledger->balance(Ledger::RIDER_CASH, $this->courier->id));
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '299.00'])->assertStatus(422);
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '300.00'])->assertSessionHasNoErrors();

        $this->assertSame(ReturnRequest::COMPLETED, $r->fresh()->status);
        $this->assertSame('partially_refunded', $order->fresh()->payment_status);
        $this->assertSame(9, $this->mug->fresh()->stock); // the returned mug was restocked
        $this->assertSame([0, 34500], [$ledger->balance(Ledger::RIDER_CASH, $this->courier->id), $ledger->balance(Ledger::PLATFORM_CASH)]);

        // Settlement only after the return window.
        $this->actingAs($this->admin)->post('/admin/finance/settle')->assertSessionHas('success', '0 order(s) settled.');
        $this->travel((int) config('picksell.return_window_days') + 1)->days();
        $this->actingAs($this->admin)->post('/admin/finance/settle')->assertSessionHas('success', '1 order(s) settled.');
        $this->assertSame(27000, -$ledger->balance(Ledger::SELLER_PAYABLE, $this->seller->id));

        // Payout: created by one admin, approved by another, completed with a reference and date.
        $this->travel(1)->days();
        $this->actingAs($this->admin)->post('/admin/finance/payouts', [
            'period_start' => LocalTime::today()->subDays(30)->toDateString(), 'period_end' => LocalTime::today()->subDay()->toDateString(),
        ])->assertSessionHasNoErrors();
        $payout = Payout::sole();
        $this->assertSame(27000, $payout->amount_cents);
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payout->id}", ['action' => 'approve'])->assertStatus(422); // same admin
        $this->actingAs($secondAdmin)->patch("/admin/finance/payouts/{$payout->id}", ['action' => 'approve'])->assertSessionHasNoErrors();
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payout->id}", [
            'action' => 'complete', 'reference' => 'BDO-E2E-1', 'disbursed_on' => LocalTime::today()->toDateString(),
        ])->assertSessionHasNoErrors();

        // Every peso accounted for.
        $this->assertSame('completed', $payout->fresh()->status);
        $this->assertSame(0, $ledger->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(7500, $ledger->balance(Ledger::PLATFORM_CASH)); // ₱645 − ₱300 refund − ₱270 payout
        $this->assertSame(-7500, $ledger->balance(Ledger::PLATFORM_REVENUE)); // ₱30 commission + ₱45 shipping
        $this->assertSame(0, (int) LedgerEntry::sum('amount_cents'));
        $this->actingAs($this->admin)->get('/admin/finance')->assertOk()->assertSee('balanced');
    }
}
