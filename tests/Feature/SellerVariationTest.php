<?php

namespace Tests\Feature;

use App\Models\CartItem;
use App\Models\ProductVariation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\BuildsMarketplace;
use Tests\TestCase;

/** Sellers manage product options; the buyer cart and checkout respect their stock. */
class SellerVariationTest extends TestCase
{
    use RefreshDatabase, BuildsMarketplace;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildMarketplace();
    }

    private function add(string $type, string $value, int $stock)
    {
        return $this->actingAs($this->seller)->from("/seller/inventory/{$this->mug->id}/options")
            ->post("/seller/inventory/{$this->mug->id}/options", compact('type', 'value', 'stock'));
    }

    public function test_seller_adds_edits_and_removes_options_with_their_own_stock(): void
    {
        $this->add('color', 'White', 3)->assertSessionHasNoErrors();
        $this->add('Size', 'L', 0)->assertSessionHasNoErrors();
        $this->add('Color', 'white', 5)->assertSessionHasErrors('value'); // duplicate, case-insensitive
        $this->add('Color', '', 5)->assertSessionHasErrors('value');
        $this->add('Color', 'Black', -1)->assertSessionHasErrors('stock');

        $white = ProductVariation::where('value', 'White')->sole();
        $this->assertSame('Color', $white->type);
        $this->actingAs($this->seller)->get("/seller/inventory/{$this->mug->id}/options")->assertOk()->assertSee('White')->assertSee('Sold out');

        $this->actingAs($this->seller)->patch("/seller/inventory/{$this->mug->id}/options/{$white->id}", ['type' => 'Color', 'value' => 'White', 'stock' => 7])
            ->assertSessionHasNoErrors();
        $this->assertSame(7, $white->fresh()->stock);

        // Other sellers can't touch them.
        $other = $this->makeUser('seller', 'other-seller@test.ph');
        $this->actingAs($other)->get("/seller/inventory/{$this->mug->id}/options")->assertForbidden();
        $this->actingAs($other)->patch("/seller/inventory/{$this->mug->id}/options/{$white->id}", ['type' => 'Color', 'value' => 'X', 'stock' => 1])->assertForbidden();
        $this->actingAs($other)->delete("/seller/inventory/{$this->mug->id}/options/{$white->id}")->assertForbidden();
    }

    public function test_buyers_must_choose_options_and_stock_is_checked_per_option(): void
    {
        $this->add('Color', 'White', 3);
        $this->add('Size', 'L', 0);
        $this->add('Size', 'M', 5);
        $white = ProductVariation::where('value', 'White')->value('id');
        $large = ProductVariation::where('value', 'L')->value('id');
        $medium = ProductVariation::where('value', 'M')->value('id');

        Sanctum::actingAs($this->buyer);
        $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1])->assertStatus(422); // must pick options
        $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1, 'variation_ids' => [$white, $large]])->assertStatus(422); // L sold out
        $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 4, 'variation_ids' => [$white, $medium]])->assertStatus(422); // only 3 White
        $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 2, 'variation_ids' => [$white, $medium]])->assertCreated();
    }

    public function test_removing_an_option_clears_cart_lines_that_chose_it(): void
    {
        $this->add('Color', 'White', 3);
        $white = ProductVariation::where('value', 'White')->sole();
        Sanctum::actingAs($this->buyer);
        $this->postJson('/api/buyer/cart', ['product_id' => $this->mug->id, 'quantity' => 1, 'variation_ids' => [$white->id]])->assertCreated();
        $this->useWebGuard();

        $this->actingAs($this->seller)->delete("/seller/inventory/{$this->mug->id}/options/{$white->id}")->assertSessionHasNoErrors();
        $this->assertNull(ProductVariation::find($white->id));
        $this->assertSame(0, CartItem::count());
    }
}
