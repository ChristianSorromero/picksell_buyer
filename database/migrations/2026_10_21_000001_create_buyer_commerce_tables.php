<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // BUY-A03 Address Manager
        Schema::create('buyer_addresses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('label', ['home', 'work', 'other'])->default('home');
            $table->string('recipient_name');
            $table->string('phone', 11); // 09XXXXXXXXX
            $table->string('province');
            $table->string('municipality');
            $table->string('barangay');
            $table->string('street');
            $table->string('house_no')->nullable();
            $table->string('postal_code', 4)->nullable();
            $table->string('landmark')->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();
        });

        // COM-C07 / BUY-A05 My Picks
        Schema::create('wishlist_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('product_id')->constrained('products')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'product_id']);
        });

        // COM-C14 Voucher Selector / BUY-A07 Voucher Wallet
        Schema::create('vouchers', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->enum('scope', ['platform', 'store'])->default('platform');
            $table->foreignId('seller_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->enum('type', ['fixed', 'percent']);
            $table->decimal('value', 10, 2);
            $table->decimal('min_spend', 10, 2)->default(0);
            $table->decimal('max_discount', 10, 2)->nullable();
            $table->unsignedInteger('usage_limit')->nullable(); // total redemptions
            $table->boolean('is_limited')->default(false);
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->boolean('active')->default(true);
            $table->timestamps();
        });

        // Variations are flat (type,value) rows; a cart line can pick one per type.
        Schema::table('cart_items', function (Blueprint $table) {
            $table->json('variation_ids')->nullable()->after('variation_id');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->string('checkout_ref')->nullable()->index()->after('order_number');
            $table->string('variation_label')->nullable()->after('quantity');
            $table->json('variation_ids')->nullable()->after('variation_label');
            $table->decimal('unit_price', 10, 2)->nullable()->after('variation_ids');
            $table->decimal('subtotal', 10, 2)->nullable()->after('unit_price');
            $table->decimal('discount', 10, 2)->default(0)->after('subtotal');
            $table->string('voucher_code')->nullable()->after('discount');
            $table->decimal('shipping_fee', 10, 2)->default(0)->after('voucher_code');
            $table->decimal('service_fee', 10, 2)->default(0)->after('shipping_fee');
            $table->decimal('total', 10, 2)->nullable()->after('service_fee');
            $table->string('shipping_option')->nullable()->after('total');
            $table->date('estimated_delivery_from')->nullable()->after('shipping_option');
            $table->date('estimated_delivery_to')->nullable()->after('estimated_delivery_from');
            $table->string('payment_method')->nullable()->after('estimated_delivery_to');
            $table->string('payment_status')->default('unpaid')->after('payment_method');
            $table->json('ship_to')->nullable()->after('payment_status');
            $table->timestamp('cancelled_at')->nullable()->after('delivered_at');
            $table->string('cancel_reason')->nullable()->after('cancelled_at');
            $table->timestamp('rated_at')->nullable()->after('feedback');
        });

        // LOG-C02 Tracking Event / LOG-C13 Status History
        Schema::create('order_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->string('status');
            $table->string('title');
            $table->string('description')->nullable();
            $table->string('location')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->index(['order_id', 'occurred_at']);
        });

        // BUY-C11 Return Request / BUY-C12 Refund Status
        Schema::create('return_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->unique()->constrained('orders')->cascadeOnDelete();
            $table->foreignId('buyer_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedInteger('quantity');
            $table->string('reason');
            $table->text('details')->nullable();
            $table->json('evidence_paths')->nullable();
            $table->decimal('refund_amount', 10, 2);
            $table->string('refund_to');
            $table->enum('status', ['requested', 'under_review', 'processing', 'refunded', 'rejected'])->default('requested');
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamp('processing_at')->nullable();
            $table->timestamp('refunded_at')->nullable();
            $table->timestamp('rejected_at')->nullable();
            $table->text('resolution_note')->nullable();
            $table->timestamps();
        });

        // BUY-C10 Report Problem → admin complaints queue
        Schema::table('complaints', function (Blueprint $table) {
            $table->foreignId('order_id')->nullable()->after('against_user_id')->constrained('orders')->nullOnDelete();
            $table->string('category')->nullable()->after('order_id');
            $table->json('evidence_paths')->nullable()->after('evidence_path');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('notifications_seen_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('notifications_seen_at'));
        Schema::table('complaints', function (Blueprint $table) {
            $table->dropConstrainedForeignId('order_id');
            $table->dropColumn(['category', 'evidence_paths']);
        });
        Schema::dropIfExists('return_requests');
        Schema::dropIfExists('order_events');
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'checkout_ref', 'variation_label', 'variation_ids', 'unit_price', 'subtotal',
                'discount', 'voucher_code', 'shipping_fee', 'service_fee', 'total', 'shipping_option',
                'estimated_delivery_from', 'estimated_delivery_to', 'payment_method', 'payment_status',
                'ship_to', 'cancelled_at', 'cancel_reason', 'rated_at',
            ]);
        });
        Schema::table('cart_items', fn (Blueprint $t) => $t->dropColumn('variation_ids'));
        Schema::dropIfExists('vouchers');
        Schema::dropIfExists('wishlist_items');
        Schema::dropIfExists('buyer_addresses');
    }
};
