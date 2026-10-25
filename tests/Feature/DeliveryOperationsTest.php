<?php

namespace Tests\Feature;

use App\Models\DeliveryAttempt;
use App\Models\LedgerEntry;
use App\Support\OrderStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** Proof of delivery, failed attempts, retries and return to sender. */
class DeliveryOperationsTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
        Storage::fake('local');
    }

    private function failAttempt($order, string $reason = 'Buyer not available')
    {
        return $this->actingAs($this->courier)->post("/courier/orders/{$order->id}/failed", ['reason' => $reason]);
    }

    public function test_delivery_records_proof_separately_from_the_cod_cash(): void
    {
        $order = $this->outForDelivery($this->placeOrder());

        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'completed', 'cash_collected' => '345.00'])
            ->assertSessionHasErrors('recipient_name');
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", [
            'status' => 'completed', 'cash_collected' => '345.00', 'recipient_name' => 'Ana Reyes (sister)',
            'proof_photo' => UploadedFile::fake()->image('doorstep.jpg'),
        ])->assertSessionHasNoErrors();

        $attempt = DeliveryAttempt::sole();
        $this->assertSame('delivered', $attempt->outcome);
        $this->assertSame('Ana Reyes (sister)', $attempt->recipient_name);
        Storage::disk('local')->assertExists($attempt->proof_photo_path);
        $this->assertSame('collected', $order->fresh()->payment_status);
        // The cash is a separate ledger event; the attempt carries no money.
        $this->assertSame(2, LedgerEntry::count());

        // Photo is private: admin and logistics only.
        $this->actingAs($this->buyer)->get("/documents/delivery-attempts/{$attempt->id}")->assertForbidden();
        $this->actingAs($this->seller)->get("/documents/delivery-attempts/{$attempt->id}")->assertForbidden();
        $this->actingAs($this->logistics)->get("/documents/delivery-attempts/{$attempt->id}")->assertOk();
        $this->actingAs($this->admin)->get("/documents/delivery-attempts/{$attempt->id}")->assertOk();
    }

    public function test_failed_attempts_are_recorded_retried_and_capped(): void
    {
        config(['picksell.delivery.max_attempts' => 2]);
        $order = $this->outForDelivery($this->placeOrder());

        $this->failAttempt($order, 'Made-up reason')->assertSessionHasErrors('reason');
        $this->actingAs($this->otherCourier)->post("/courier/orders/{$order->id}/failed", ['reason' => 'Buyer not available'])->assertForbidden();
        $this->failAttempt($order)->assertSessionHasNoErrors();

        $order->refresh();
        $this->assertSame(OrderStatus::DELIVERY_FAILED, $order->canonical_status);
        $this->assertSame(1, $order->delivery_attempts);
        $this->assertSame('unpaid', $order->payment_status);
        $this->assertSame(0, LedgerEntry::count()); // no cash, no money events

        // The buyer sees the failed attempt; a failed parcel can't be marked delivered or failed again.
        Sanctum::actingAs($this->buyer);
        $this->getJson("/api/buyer/orders/{$order->id}")->assertJsonPath('order.status', 'delivery_failed');
        $this->useWebGuard();
        $this->deliver($order)->assertStatus(422);
        $this->failAttempt($order)->assertStatus(422);

        // Retry once more, fail again: the cap is reached.
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertSessionHasNoErrors();
        $this->failAttempt($order, 'Buyer refused the parcel')->assertSessionHasNoErrors();
        $this->actingAs($this->courier)->patch("/courier/orders/{$order->id}/status", ['status' => 'shipped'])->assertStatus(422);
        $this->assertSame(['failed', 'failed'], DeliveryAttempt::orderBy('id')->pluck('outcome')->all());
    }

    public function test_an_undeliverable_parcel_returns_to_the_seller_without_charging_anyone(): void
    {
        $order = $this->outForDelivery($this->placeOrder());
        $this->assertSame(9, $this->mug->fresh()->stock);

        $this->actingAs($this->logistics)->post("/logistics/parcels/{$order->id}/return-to-sender", ['reason' => 'x'])->assertStatus(422); // not failed yet
        $this->failAttempt($order, 'Wrong or incomplete address');
        $this->actingAs($this->seller)->post("/seller/orders/{$order->id}/returned-parcel", ['restock' => 1])->assertStatus(422); // not on its way back

        $this->actingAs($this->logistics)->post("/logistics/parcels/{$order->id}/return-to-sender", ['reason' => 'Address cannot be found'])->assertSessionHasNoErrors();
        $this->assertSame(OrderStatus::RETURNED, $order->fresh()->canonical_status);

        $other = $this->makeUser('seller', 'other-seller@test.ph');
        $this->actingAs($other)->post("/seller/orders/{$order->id}/returned-parcel", ['restock' => 1])->assertForbidden();
        $this->actingAs($this->seller)->get("/seller/orders/{$order->id}")->assertOk()->assertSee('being returned to you');
        $this->actingAs($this->seller)->post("/seller/orders/{$order->id}/returned-parcel", ['restock' => 1])->assertSessionHasNoErrors();
        $this->actingAs($this->seller)->post("/seller/orders/{$order->id}/returned-parcel", ['restock' => 1])->assertStatus(422);

        $order->refresh();
        $this->assertSame('cancelled', $order->status);
        $this->assertSame(OrderStatus::RETURNED, $order->canonical_status);
        $this->assertSame('unpaid', $order->payment_status);
        $this->assertSame(10, $this->mug->fresh()->stock);
        $this->assertSame(0, LedgerEntry::count());
    }

    public function test_buyer_cancellation_before_dispatch_creates_no_refund(): void
    {
        $order = $this->placeOrder();
        Sanctum::actingAs($this->buyer);
        $this->postJson("/api/buyer/orders/{$order->id}/cancel", ['reason' => 'Ordered by mistake'])->assertOk();
        $this->assertSame('unpaid', $order->fresh()->payment_status);
        $this->assertSame(0, LedgerEntry::count());
        $this->postJson("/api/buyer/orders/{$order->id}/return", ['quantity' => 1, 'reason' => 'Changed my mind'])->assertStatus(422);
    }
}
