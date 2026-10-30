<?php

namespace Tests\Feature\Api;

use App\Models\Message;
use App\Models\RecentlyViewedProduct;
use App\Models\WishlistItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Api\Concerns\BuildsMarketplace;
use Tests\TestCase;

class SharedListsAndChatTest extends TestCase
{
    use BuildsMarketplace, RefreshDatabase;

    public function test_the_wishlist_is_the_same_rows_as_the_website(): void
    {
        $seller = $this->seller();
        $lamp = $this->product($seller);
        $mug = $this->product($seller, ['name' => 'Mug']);
        $buyer = $this->actingAsBuyer();
        // Saved on the website.
        WishlistItem::create(['user_id' => $buyer->id, 'product_id' => $mug->id]);

        $this->postJson("/api/buyer/wishlist/{$lamp->id}")->assertCreated();
        $this->postJson("/api/buyer/wishlist/{$lamp->id}")->assertCreated();
        $this->assertSame(2, WishlistItem::where('user_id', $buyer->id)->count());
        $this->assertEqualsCanonicalizing(['Desk Lamp', 'Mug'], collect($this->getJson('/api/buyer/wishlist')->json('products'))->pluck('name')->all());
        $this->getJson("/api/products/{$lamp->id}")->assertJsonPath('product.wishlisted', true);

        $mug->update(['status' => 'archived']);
        $this->assertSame(['Desk Lamp'], collect($this->getJson('/api/buyer/wishlist')->json('products'))->pluck('name')->all());
        $this->postJson("/api/buyer/wishlist/{$mug->id}")->assertNotFound();

        $this->deleteJson("/api/buyer/wishlist/{$lamp->id}")->assertOk();
        $this->assertFalse(WishlistItem::where('product_id', $lamp->id)->exists());
    }

    public function test_opening_products_fills_the_shared_recently_viewed_list(): void
    {
        $seller = $this->seller();
        $lamp = $this->product($seller);
        $mug = $this->product($seller, ['name' => 'Mug']);

        $this->getJson("/api/products/{$lamp->id}")->assertOk(); // guests leave no history
        $this->assertSame(0, RecentlyViewedProduct::count());

        $buyer = $this->buyer();
        $token = $buyer->createToken('mobile')->plainTextToken;
        $this->withToken($token)->getJson("/api/products/{$lamp->id}");
        $this->travel(1)->minutes();
        $this->withToken($token)->getJson("/api/products/{$mug->id}");

        $this->withToken($token)->getJson('/api/buyer/recently-viewed')->assertOk()
            ->assertJsonPath('products.0.name', 'Mug')->assertJsonPath('products.1.name', 'Desk Lamp');
        $this->withToken($token)->getJson('/api/home')->assertJsonPath('recently_viewed.0.name', 'Mug');

        $this->withToken($token)->deleteJson('/api/buyer/recently-viewed')->assertOk();
        $this->assertSame(0, RecentlyViewedProduct::where('user_id', $buyer->id)->count());
    }

    public function test_chat_follows_the_website_rules(): void
    {
        Mail::fake();
        $seller = $this->seller();
        $otherBuyer = $this->buyer();
        $pendingSeller = $this->person('seller', ['status' => 'pending']);
        $admin = $this->admin();
        $buyer = $this->actingAsBuyer();

        $this->postJson('/api/chat/send', ['receiver_id' => $seller->id, 'body' => 'Is the lamp warm white?'])->assertCreated()->assertJsonPath('is_mine', true);
        $this->postJson('/api/chat/send', ['receiver_id' => $otherBuyer->id, 'body' => 'hi'])->assertNotFound();
        $this->postJson('/api/chat/send', ['receiver_id' => $pendingSeller->id, 'body' => 'hi'])->assertNotFound();

        // The seller sees it in the website chat and gets the website's alert.
        $this->assertSame(1, Message::where('receiver_id', $seller->id)->count());
        $this->assertStringContainsString('new message', $seller->notifications()->sole()->data);

        Message::create(['sender_id' => $seller->id, 'receiver_id' => $buyer->id, 'body' => 'Yes it is.', 'read' => false]);
        $this->getJson('/api/chat/contacts')->assertOk()->assertJsonPath('contacts.0.unread', 1);
        $this->getJson("/api/chat/messages/{$seller->id}")->assertOk()->assertJsonCount(2, 'messages');
        $this->assertSame(0, Message::where('receiver_id', $buyer->id)->where('read', false)->count());

        // Support (admin) appears once the buyer has written to it.
        $this->postJson('/api/chat/send', ['receiver_id' => $admin->id, 'body' => 'Help please'])->assertCreated();
        $this->assertContains('PickSell Support', collect($this->getJson('/api/chat/contacts')->json('contacts'))->pluck('name'));
    }
}
