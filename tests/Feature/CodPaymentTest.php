<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\LedgerEntry;
use App\Services\DuplicatePosting;
use App\Services\Ledger;
use App\Support\Money;
use Illuminate\Foundation\Testing\RefreshDatabase;
use LogicException;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** G07: Cash on Delivery only; placed ≠ delivered ≠ collected ≠ paid. */
class CodPaymentTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    public function test_cash_on_delivery_is_the_only_payment_method_offered_or_accepted(): void
    {
        $this->getJson('/api/payment-methods')->assertOk()->assertExactJson(['payment_methods' => [
            ['code' => 'cod', 'name' => 'Cash on Delivery', 'description' => 'Pay in cash when you receive your order', 'available' => true],
        ]]);
        $this->asBuyerApi();
        $this->getJson('/api/buyer/orders/options')->assertJsonPath('refund_methods', [['code' => 'cash', 'name' => 'Cash, handed over by a Picksell rider']]);

        $item = $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1])->json('cart_item_id');
        foreach (['gcash', 'maya', 'card', 'bank_transfer'] as $method) {
            $this->postJson('/api/buyer/checkout', ['item_ids' => [$item], 'address_id' => 1, 'payment_method' => $method])
                ->assertStatus(422)->assertJsonValidationErrors('payment_method');
        }

        // Website too.
        $this->useWebGuard();
        $this->buyer->update(['province' => 'Metro Manila', 'municipality' => 'Quezon City', 'barangay' => 'Diliman']);
        $this->actingAs($this->buyer)->post('/buyer/cart/checkout', ['item_ids' => [$item], 'payment_method' => 'gcash'])
            ->assertSessionHasErrors('payment_method');
        $this->actingAs($this->buyer)->get('/buyer/cart')->assertOk()->assertDontSee('GCash')->assertDontSee('Maya');
    }

    public function test_placing_or_delivering_an_order_does_not_mark_it_paid(): void
    {
        $order = $this->placeOrder();
        $this->assertSame('unpaid', $order->payment_status);
        $this->assertSame(0, LedgerEntry::count());

        $order = $this->outForDelivery($order);
        $this->deliver($order)->assertRedirect();

        $order->refresh();
        $this->assertSame('delivered', $order->canonical_status);
        $this->assertSame('collected', $order->payment_status);
        $this->assertNull($order->paid_at);
        $this->assertSame($this->courier->id, $order->cod_collected_by);
        $this->assertSame(34500, app(Ledger::class)->balance(Ledger::RIDER_CASH, $this->courier->id));
    }

    public function test_the_rider_must_record_exactly_the_cash_due(): void
    {
        $order = $this->outForDelivery($this->placeOrder());

        $this->deliver($order, '300.00')->assertStatus(422);
        $this->deliver($order, '345.01')->assertStatus(422);

        $this->assertSame('out_for_delivery', $order->fresh()->canonical_status);
        $this->assertSame('unpaid', $order->fresh()->payment_status);
        $this->assertSame(0, LedgerEntry::count());
    }

    public function test_only_the_assigned_rider_can_record_collection_and_only_once(): void
    {
        $order = $this->outForDelivery($this->placeOrder());

        $this->actingAs($this->otherCourier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00'])
            ->assertForbidden();
        $this->actingAs($this->buyer)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00'])
            ->assertForbidden();
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/rate", ['rating' => 5])->assertStatus(422); // not delivered
        $this->useWebGuard();

        $this->deliver($order)->assertRedirect();
        $this->deliver($order)->assertStatus(422);
        $this->assertSame(1, AuditLog::where('action', 'cod_collected')->count());
        $this->assertSame(2, LedgerEntry::count());
    }

    public function test_cash_handed_in_is_confirmed_once_by_the_sorting_center(): void
    {
        $order = $this->outForDelivery($this->placeOrder());
        $other = $this->outForDelivery($this->placeOrder(), $this->otherCourier);
        $this->deliver($order);

        // Not handed in yet: another rider's or an uncollected order can't be confirmed.
        $this->remit([$other])->assertStatus(422);
        $this->actingAs($this->buyer)->post("/logistics/cash/riders/{$this->courier->id}/remit", ['order_ids' => [$order->id]])->assertForbidden();
        $this->actingAs($this->courier)->post("/logistics/cash/riders/{$this->courier->id}/remit", ['order_ids' => [$order->id]])->assertForbidden();

        $this->actingAs($this->logistics)->get('/logistics/cash')->assertOk()->assertSee($order->order_number)->assertSee('₱345.00');
        $this->remit([$order])->assertSessionHasNoErrors();

        $order->refresh();
        $this->assertSame('paid', $order->payment_status);
        $this->assertNotNull($order->paid_at);
        $this->assertSame($this->logistics->id, $order->payment_confirmed_by);
        $ledger = app(Ledger::class);
        $this->assertSame(0, $ledger->balance(Ledger::RIDER_CASH, $this->courier->id));
        $this->assertSame(34500, $ledger->balance(Ledger::PLATFORM_CASH));
        $this->assertSame(0, (int) LedgerEntry::sum('amount_cents'));

        $this->remit([$order])->assertStatus(422);
        $this->assertSame(['cod_collected', 'cod_remitted'], $order->auditLogs()->reorder('id')->pluck('action')->all());
    }

    public function test_ledger_rejects_duplicates_unbalanced_postings_and_edits(): void
    {
        $ledger = app(Ledger::class);
        $ledger->post('test', 'test:1', [[Ledger::PLATFORM_CASH, null, 100], [Ledger::PLATFORM_REVENUE, null, -100]]);

        $this->assertThrows(fn () => $ledger->post('test', 'test:1', [[Ledger::PLATFORM_CASH, null, 100], [Ledger::PLATFORM_REVENUE, null, -100]]), DuplicatePosting::class);
        $this->assertThrows(fn () => $ledger->post('test', 'test:2', [[Ledger::PLATFORM_CASH, null, 100], [Ledger::PLATFORM_REVENUE, null, -99]]), LogicException::class);
        $this->assertThrows(fn () => LedgerEntry::first()->update(['amount_cents' => 1]), LogicException::class);
        $this->assertThrows(fn () => LedgerEntry::first()->delete(), LogicException::class);
    }

    public function test_money_helper_avoids_floating_point_rounding(): void
    {
        $this->assertSame(64550, Money::cents('645.5'));
        $this->assertSame(64550, Money::cents(645.5));
        $this->assertSame(30, Money::cents('0.1') + Money::cents('0.2'));
        $this->assertSame('₱1,234,567.89', Money::format(123456789));
        $this->assertSame(3450, Money::times(34500, '0.10'));
        $this->assertSame(1, Money::times(150, '0.005')); // 0.75 → 1 centavo, half-up
    }
}
