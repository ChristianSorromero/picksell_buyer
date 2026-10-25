<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\LedgerEntry;
use App\Models\Payout;
use App\Models\ReturnRequest;
use App\Models\Voucher;
use App\Services\Ledger;
use App\Services\Settlements;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** G10: settlement only after cash, return window and returns; manual, admin-approved payouts. */
class SettlementPayoutTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    private function settleAfterWindow(): int
    {
        $this->travel(8)->days();
        return app(Settlements::class)->settleEligible();
    }

    private function ledger(): Ledger
    {
        return app(Ledger::class);
    }

    /** The last month up to yesterday, as of the (travelled) current time. */
    private function periodToYesterday(): array
    {
        return ['period_start' => now()->subDays(30)->toDateString(), 'period_end' => now()->subDay()->toDateString()];
    }

    public function test_orders_settle_only_after_cash_is_handed_in_and_the_return_window_passes(): void
    {
        $paid = $this->paidOrder();
        $collectedOnly = $this->outForDelivery($this->placeOrder());
        $this->deliver($collectedOnly);

        $this->assertSame(0, app(Settlements::class)->settleEligible()); // inside the 7-day window
        $this->assertSame(1, $this->settleAfterWindow());                 // collected-only never settles
        $this->assertNotNull($paid->fresh()->settled_at);
        $this->assertNull($collectedOnly->fresh()->settled_at);

        // ₱345 = ₱300 item + ₱45 shipping. Commission 10% of ₱300.
        $this->assertSame(27000, -$this->ledger()->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(7500, -$this->ledger()->balance(Ledger::PLATFORM_REVENUE));
        $this->assertSame(0, $this->ledger()->balance(Ledger::ORDER_FUNDS, null, $paid->id));
        $this->assertSame(0, (int) LedgerEntry::sum('amount_cents'));

        // Settling twice is refused.
        $this->assertSame(0, app(Settlements::class)->settleEligible());
        $this->assertThrows(fn () => app(Settlements::class)->settle($paid));
    }

    public function test_an_open_return_holds_settlement_and_refunds_reduce_the_seller_share(): void
    {
        $order = $this->paidOrder(2); // ₱645
        $this->asBuyerApi();
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Damaged or defective item'])->assertCreated();
        $this->useWebGuard();
        $r = ReturnRequest::first();

        $this->assertSame(0, $this->settleAfterWindow()); // open return blocks it

        $this->actingAs($this->admin)->post("/admin/returns/{$r->id}/approve");
        $this->actingAs($this->seller)->post("/seller/returns/{$r->id}/propose", ['resolution_type' => 'partial_refund', 'resolution_amount' => '100.00']);
        $this->asBuyerApi();
        $this->postJson("/api/buyer/returns/{$r->id}/accept");
        $this->useWebGuard();
        $this->actingAs($this->logistics)->post("/logistics/refunds/{$r->id}/release", ['courier_id' => $this->courier->id]);
        $this->actingAs($this->courier)->post("/courier/refunds/{$r->id}/handover", ['amount' => '100.00'])->assertSessionHasNoErrors();

        $this->assertSame(1, app(Settlements::class)->settleEligible());
        // Seller: (₱600 − ₱100 refund) − 10% commission = ₱450. Platform: ₱545 kept − ₱450 = ₱95.
        $this->assertSame(45000, -$this->ledger()->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(9500, -$this->ledger()->balance(Ledger::PLATFORM_REVENUE));
        $this->assertSame(0, $this->ledger()->balance(Ledger::ORDER_FUNDS, null, $order->id));
    }

    public function test_rider_pay_withholding_and_platform_vouchers_follow_configuration(): void
    {
        config([
            'picksell.finance.rider_fee_per_delivery' => '40.00',
            'picksell.finance.withholding.enabled'    => true,
        ]);
        Voucher::create(['code' => 'PICK50', 'scope' => 'platform', 'type' => 'fixed', 'value' => 50, 'min_spend' => 0, 'active' => true]);
        $order = $this->paidOrder(1, ['voucher_code' => 'PICK50']); // buyer pays ₱250 + ₱45 = ₱295
        $this->assertSame(29500, $order->totalCents());

        $this->settleAfterWindow();
        $b = app(Settlements::class)->breakdown($order);

        // Platform funds its voucher: seller is credited the ₱300 list price.
        $this->assertSame(30000, $b['seller_gross']);
        $this->assertSame(3000, $b['commission']);
        $this->assertSame(150, $b['withholding']);   // 1% × ½ × ₱300 (RR 16-2023)
        $this->assertSame(26850, $b['seller']);
        $this->assertSame(4000, $b['rider']);
        $this->assertSame(-1500, $b['platform']);    // ₱295 − ₱268.50 − ₱1.50 − ₱40
        $this->assertSame(26850, -$this->ledger()->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(4000, -$this->ledger()->balance(Ledger::RIDER_PAYABLE, $this->courier->id));
        $this->assertSame(150, -$this->ledger()->balance(Ledger::WITHHOLDING_TAX));
    }

    public function test_payouts_are_admin_approved_recorded_once_and_released_on_failure(): void
    {
        config(['picksell.finance.rider_fee_per_delivery' => '40.00']);
        $this->paidOrder();
        $this->paidOrder();
        $this->settleAfterWindow();
        $period = ['period_start' => now()->subDays(30)->toDateString(), 'period_end' => now()->subDay()->toDateString()];

        // Only admins manage payouts.
        $this->actingAs($this->seller)->post('/admin/finance/payouts', $period)->assertForbidden();

        $this->travel(1)->days();
        $this->actingAs($this->admin)->post('/admin/finance/payouts', $this->periodToYesterday())->assertSessionHasNoErrors();
        $sellerPayout = Payout::where('payee_role', 'seller')->sole();
        $riderPayout = Payout::where('payee_role', 'courier')->sole();
        $this->assertSame(54000, $sellerPayout->amount_cents);
        $this->assertSame(8000, $riderPayout->amount_cents);

        // Generating again doesn't pay the same shares twice.
        $this->actingAs($this->admin)->post('/admin/finance/payouts', $this->periodToYesterday());
        $this->assertSame(2, Payout::count());

        // Can't be marked paid before approval, or without a reference.
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$sellerPayout->id}", ['action' => 'complete', 'reference' => 'BDO-1'])->assertStatus(422);
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$sellerPayout->id}", ['action' => 'approve'])->assertSessionHasNoErrors();
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$sellerPayout->id}", ['action' => 'complete'])->assertSessionHasErrors('reference');
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$sellerPayout->id}", ['action' => 'complete', 'reference' => 'BDO-1'])->assertSessionHasNoErrors();
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$sellerPayout->id}", ['action' => 'complete', 'reference' => 'BDO-1'])->assertStatus(422);

        $this->assertSame('completed', $sellerPayout->fresh()->status);
        $this->assertSame(0, $this->ledger()->balance(Ledger::SELLER_PAYABLE, $this->seller->id));
        $this->assertSame(69000 - 54000, $this->ledger()->balance(Ledger::PLATFORM_CASH));

        // A failed transfer releases the rider's shares so they can be paid again.
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$riderPayout->id}", ['action' => 'approve']);
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$riderPayout->id}", ['action' => 'processing']);
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$riderPayout->id}", ['action' => 'fail', 'reason' => 'GCash number invalid'])->assertSessionHasNoErrors();
        $this->assertSame(8000, -$this->ledger()->balance(Ledger::RIDER_PAYABLE, $this->courier->id));
        $this->actingAs($this->admin)->post('/admin/finance/payouts', $this->periodToYesterday());
        $this->assertSame(8000, Payout::where('payee_role', 'courier')->where('status', 'pending')->sole()->amount_cents);

        $this->assertSame(['created', 'approved', 'completed'], $sellerPayout->auditLogs()->reorder('id')->pluck('action')->all());
        $this->assertSame(0, (int) LedgerEntry::sum('amount_cents'));
    }

    public function test_a_second_admin_can_be_required_to_approve(): void
    {
        config(['picksell.finance.payout_requires_second_admin' => true]);
        $this->paidOrder();
        $this->settleAfterWindow();
        $payouts = app(Settlements::class)->generatePayouts(CarbonImmutable::now()->subMonth(), CarbonImmutable::now(), $this->admin);

        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payouts[0]->id}", ['action' => 'approve'])->assertStatus(422);
        $second = $this->makeUser('admin', 'admin2@test.ph');
        $this->actingAs($second)->patch("/admin/finance/payouts/{$payouts[0]->id}", ['action' => 'approve'])->assertSessionHasNoErrors();
        $this->assertSame($second->id, $payouts[0]->fresh()->approved_by);
    }

    public function test_reconciliation_and_role_pages_show_balances(): void
    {
        $paid = $this->paidOrder();
        $collected = $this->outForDelivery($this->placeOrder());
        $this->deliver($collected);
        $this->settleAfterWindow();

        $rec = app(Settlements::class)->reconciliation();
        $this->assertSame([$this->courier->id => 34500], $rec['rider_cash']);
        $this->assertSame(34500, $rec['platform_cash']);
        $this->assertSame(1, $rec['collected_orders']->count());
        $this->assertSame(0, $rec['discrepancies']['ledger_out_of_balance']);
        $this->assertSame([], $rec['discrepancies']['settled_with_open_funds']);
        $this->assertFalse($rec['rider_pay_configured']);

        $this->actingAs($this->admin)->get('/admin/finance')->assertOk()->assertSee('₱270.00')->assertSee('balanced');
        $this->actingAs($this->seller)->get('/seller/payouts')->assertOk()->assertSee($paid->order_number)->assertSee('₱270.00');
        $this->actingAs($this->courier)->get('/courier/orders')->assertOk()->assertSee('₱345.00');
        $this->assertGreaterThan(0, AuditLog::where('action', 'settled')->count());
    }
}
