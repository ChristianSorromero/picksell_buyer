<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Additive only: delivery attempts and proof of delivery, case-based
 * refund timing and liability, legacy-payment review, rider pay records,
 * payout disbursement dates and seller tax profiles (withholding prep).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedTinyInteger('delivery_attempts')->default(0)->after('delivered_at');
            // Orders delivered before COD tracking: 'unverifiable' once reviewed without evidence.
            $table->string('payment_review', 20)->nullable()->after('settled_at');
            $table->text('payment_review_note')->nullable()->after('payment_review');
            $table->timestamp('payment_backfilled_at')->nullable()->after('payment_review_note');
        });

        // Every delivery attempt, independent of the COD cash events in the ledger.
        Schema::create('delivery_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->restrictOnDelete();
            $table->foreignId('courier_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('outcome', 20);                 // delivered | failed
            $table->string('reason', 60)->nullable();      // failed attempts
            $table->string('recipient_name', 120)->nullable();
            $table->string('proof_photo_path')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('attempted_at');
            $table->index(['order_id', 'outcome']);
        });

        Schema::table('return_requests', function (Blueprint $table) {
            // after_inspection (default) | on_pickup (expedited by admin) | no_return
            $table->string('refund_timing', 20)->nullable()->after('requires_item_return');
            $table->foreignId('expedited_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('expedited_reason')->nullable();
            // Who caused the problem vs. who pays the refund, decided by admin.
            $table->string('liable_party', 20)->nullable();
            $table->string('refund_funded_by', 20)->nullable();
            $table->text('liability_note')->nullable();
            $table->foreignId('liability_set_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('pickup_courier_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('pickup_assigned_at')->nullable();
            $table->boolean('inspection_passed')->nullable();
            $table->text('inspection_note')->nullable();
        });

        // How each amount was calculated (rider pay, settlements, backfills).
        Schema::table('ledger_transactions', function (Blueprint $table) {
            $table->json('details')->nullable()->after('memo');
        });

        Schema::table('payouts', function (Blueprint $table) {
            $table->date('disbursed_on')->nullable()->after('reference');
        });

        // Information a compliant RR 16-2023 implementation needs; not used
        // for withholding until it is reviewed and enabled.
        Schema::create('seller_tax_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_id')->unique()->constrained('users')->restrictOnDelete();
            $table->string('tin', 20)->nullable();
            $table->string('bir_cor_number', 40)->nullable();       // BIR Form 2303
            $table->unsignedSmallInteger('sworn_declaration_year')->nullable();
            $table->date('sworn_declaration_received_on')->nullable();
            $table->string('exemption_type', 30)->nullable();        // e.g. lower_rate, exempt_by_law
            $table->string('exemption_reference')->nullable();
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('seller_tax_profiles');
        Schema::table('payouts', fn (Blueprint $t) => $t->dropColumn('disbursed_on'));
        Schema::table('ledger_transactions', fn (Blueprint $t) => $t->dropColumn('details'));
        Schema::table('return_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('pickup_courier_id');
            $table->dropConstrainedForeignId('liability_set_by');
            $table->dropConstrainedForeignId('expedited_by');
            $table->dropColumn(['refund_timing', 'expedited_reason', 'liable_party', 'refund_funded_by', 'liability_note',
                'pickup_assigned_at', 'inspection_passed', 'inspection_note']);
        });
        Schema::dropIfExists('delivery_attempts');
        Schema::table('orders', fn (Blueprint $t) => $t->dropColumn(['delivery_attempts', 'payment_review', 'payment_review_note', 'payment_backfilled_at']));
    }
};
