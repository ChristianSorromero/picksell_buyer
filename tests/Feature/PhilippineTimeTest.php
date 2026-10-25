<?php

namespace Tests\Feature;

use App\Models\LedgerTransaction;
use App\Models\Order;
use App\Models\Payout;
use App\Services\Settlements;
use App\Support\LocalTime;
use Carbon\CarbonImmutable;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/**
 * Timestamps are stored in UTC and shown, grouped into days and scheduled
 * in Philippine time (UTC+8). The clock is set to the hours where the two
 * disagree on the date: 16:00–23:59 UTC is already tomorrow in Manila.
 */
class PhilippineTimeTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    public function test_storage_stays_utc_and_local_days_map_to_utc_ranges(): void
    {
        $this->assertSame('UTC', config('app.timezone'));
        $this->assertSame('Asia/Manila', LocalTime::zone());

        $this->travelTo(CarbonImmutable::parse('2026-10-25 17:30:00', 'UTC'));
        $order = $this->placeOrder();
        // Stored as the UTC wall time…
        $this->assertSame('2026-10-25 17:30:00', DB::table('orders')->where('id', $order->id)->value('created_at'));
        // …which is 1:30 AM on the 26th in Manila.
        $this->assertSame('2026-10-26 01:30', $order->created_at->forDisplay()->format('Y-m-d H:i'));
        $this->assertSame('2026-10-25 17:30', $order->created_at->format('Y-m-d H:i'), 'forDisplay() must not change the stored value');
        $this->assertSame('2026-10-26', LocalTime::dateOf($order->created_at));
        $this->assertSame('2026-10-26', LocalTime::today()->toDateString());

        [$start, $end] = LocalTime::dayRange('2026-10-26');
        $this->assertSame('2026-10-25 16:00:00', $start->format('Y-m-d H:i:s'));
        $this->assertSame('2026-10-26 15:59:59', $end->format('Y-m-d H:i:s'));
        $this->assertSame('UTC', $start->getTimezone()->getName());
    }

    public function test_pages_show_philippine_time(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-10-25 17:30:00', 'UTC'));
        $order = $this->placeOrder();

        $this->actingAs($this->seller)->get("/seller/orders/{$order->id}")
            ->assertOk()->assertSee('Oct 26, 2026 01:30 AM')->assertDontSee('Oct 25, 2026 05:30 PM');
        $this->actingAs($this->buyer)->get('/buyer/orders')->assertOk()->assertSee('Oct 26, 2026');
    }

    public function test_reports_group_orders_by_philippine_calendar_day(): void
    {
        // 00:30 on Oct 26 in Manila, but still Oct 25 in UTC.
        $this->travelTo(CarbonImmutable::parse('2026-10-25 16:30:00', 'UTC'));
        $early = $this->placeOrder();
        // 00:30 on Oct 27 in Manila: outside the Oct 26 report.
        $this->travelTo(CarbonImmutable::parse('2026-10-26 16:30:00', 'UTC'));
        $nextDay = $this->placeOrder();
        Order::whereKey([$early->id, $nextDay->id])->update(['status' => 'completed']);

        $this->actingAs($this->admin)->get('/admin/commission?from=2026-10-26&to=2026-10-26')
            ->assertOk()->assertSee($early->order_number)->assertDontSee($nextDay->order_number);
        $this->actingAs($this->courier)->get('/courier/reports')->assertOk();
    }

    public function test_dates_entered_as_today_in_manila_are_accepted_before_utc_catches_up(): void
    {
        // 07:00 on Oct 26 in Manila; UTC is still on Oct 25.
        $this->travelTo(CarbonImmutable::parse('2026-10-25 23:00:00', 'UTC'));

        $this->actingAs($this->admin)->post("/admin/finance/sellers/{$this->seller->id}/tax-profile", [
            'sworn_declaration_received_on' => '2026-10-26',
        ])->assertSessionHasNoErrors();
        $this->actingAs($this->admin)->post("/admin/finance/sellers/{$this->seller->id}/tax-profile", [
            'sworn_declaration_received_on' => '2026-10-27',
        ])->assertSessionHasErrors('sworn_declaration_received_on');
    }

    public function test_payout_periods_follow_philippine_days(): void
    {
        config(['picksell.finance.payout_period' => 'daily']);
        $settlements = app(Settlements::class);

        // 01:00 on Oct 26 in Manila: yesterday is Oct 25, Manila time.
        $this->travelTo(CarbonImmutable::parse('2026-10-25 17:00:00', 'UTC'));
        [$start, $end] = $settlements->lastPeriod();
        $this->assertSame('2026-10-25 00:00:00', $start->format('Y-m-d H:i:s'));
        $this->assertSame('2026-10-25 23:59:59', $end->format('Y-m-d H:i:s'));

        // A settled seller line from 23:30 Manila on Oct 25 falls in that period;
        // one from 00:30 Manila on Oct 26 waits for the next.
        $this->travelTo(CarbonImmutable::parse('2026-10-15 03:00:00', 'UTC'));
        $inside = $this->paidOrder();
        $outside = $this->paidOrder();
        $this->travelTo(CarbonImmutable::parse('2026-10-25 15:30:00', 'UTC'));
        $settlements->settle($inside->fresh());
        $this->travelTo(CarbonImmutable::parse('2026-10-25 16:30:00', 'UTC'));
        $settlements->settle($outside->fresh());

        $this->travelTo(CarbonImmutable::parse('2026-10-25 17:00:00', 'UTC'));
        $payouts = $settlements->generatePayouts($start, $end, $this->admin);
        $this->assertCount(1, $payouts);
        $payout = Payout::first();
        $this->assertSame('2026-10-25', $payout->period_start->toDateString());
        $this->assertSame('2026-10-25', $payout->period_end->toDateString());
        $settledInside = LedgerTransaction::where('type', 'order_settlement')->where('order_id', $inside->id)->firstOrFail();
        $this->assertSame(
            -$settledInside->entries()->where('account', 'seller_payable')->sum('amount_cents'),
            $payout->amount_cents,
            'Only the line settled before Manila midnight is paid out',
        );

        // Today in Manila is not a finished period.
        $this->actingAs($this->admin)->post('/admin/finance/payouts', ['period_start' => '2026-10-26', 'period_end' => '2026-10-26'])
            ->assertSessionHasErrors('period_end');

        // Money sent at 01:00 Manila is disbursed "today" (Oct 26), not in the future.
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payout->id}", ['action' => 'approve'])->assertSessionHasNoErrors();
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payout->id}", ['action' => 'complete', 'reference' => 'BDO-7', 'disbursed_on' => '2026-10-27'])
            ->assertStatus(422);
        $this->actingAs($this->admin)->patch("/admin/finance/payouts/{$payout->id}", ['action' => 'complete', 'reference' => 'BDO-7', 'disbursed_on' => '2026-10-26'])
            ->assertSessionHasNoErrors();
        $this->assertSame('completed', $payout->fresh()->status);
    }

    public function test_scheduled_jobs_run_on_philippine_time(): void
    {
        $this->assertSame('Asia/Manila', config('app.schedule_timezone'));
        $events = collect(app(Schedule::class)->events());
        $settle = $events->first(fn ($e) => str_contains($e->command, 'picksell:settle-orders'));
        $this->assertNotNull($settle);
        $this->assertSame('Asia/Manila', (string) $settle->timezone);

        // 02:00 in Manila is 18:00 UTC the day before.
        $this->travelTo(CarbonImmutable::parse('2026-10-25 18:00:00', 'UTC'));
        $this->assertTrue($settle->isDue($this->app));
        $this->travelTo(CarbonImmutable::parse('2026-10-26 02:00:00', 'UTC'));
        $this->assertFalse($settle->isDue($this->app));
    }

    public function test_checkout_delivery_estimates_count_from_the_philippine_date(): void
    {
        // 06:00 on Oct 26 in Manila.
        $this->travelTo(CarbonImmutable::parse('2026-10-25 22:00:00', 'UTC'));
        $standard = collect(config('picksell.shipping_options'))->firstWhere('code', 'standard');
        $order = $this->placeOrder();

        $this->assertSame(
            CarbonImmutable::parse('2026-10-26')->addDays($standard['min_days'])->toDateString(),
            $order->estimated_delivery_from->toDateString(),
        );
    }
}
