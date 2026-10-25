<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * COD payment lifecycle, the admin-first return/refund case, and the
 * money ledger behind settlements and payouts. All money added here is in
 * integer centavos; existing decimal columns are left as they are.
 */
return new class extends Migration
{
    /** Old return statuses → the case states that replace them. */
    private const RETURN_STATUS_MAP = [
        'under_review' => 'requested',
        'processing'   => 'resolved',
        'refunded'     => 'completed',
    ];

    public function up(): void
    {
        // COD: placed → delivered + cash collected → cash handed in (paid).
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('cod_collected_at')->nullable()->after('payment_status');
            $table->foreignId('cod_collected_by')->nullable()->after('cod_collected_at')->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable()->after('cod_collected_by');
            $table->foreignId('payment_confirmed_by')->nullable()->after('paid_at')->constrained('users')->nullOnDelete();
            $table->timestamp('settled_at')->nullable()->after('payment_confirmed_by');
        });

        Schema::table('return_requests', function (Blueprint $table) {
            $table->string('status', 30)->default('requested')->change();
            $table->string('resolution_type', 30)->nullable()->after('status');
            $table->decimal('resolution_amount', 10, 2)->nullable()->after('resolution_type');
            $table->boolean('requires_item_return')->default(false)->after('resolution_amount');
            $table->text('info_request')->nullable()->after('resolution_note');
            $table->text('seller_note')->nullable()->after('info_request');
            $table->foreignId('refund_courier_id')->nullable()->after('seller_note')->constrained('users')->nullOnDelete();
            $table->timestamp('admin_approved_at')->nullable();
            $table->timestamp('proposed_at')->nullable();
            $table->timestamp('escalated_at')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamp('refund_released_at')->nullable();
            $table->timestamp('item_collected_at')->nullable();
            $table->timestamp('item_received_at')->nullable();
            $table->boolean('restocked')->default(false);
            $table->timestamp('replacement_sent_at')->nullable();
            $table->timestamp('completed_at')->nullable();
        });
        foreach (self::RETURN_STATUS_MAP as $old => $new) {
            DB::table('return_requests')->where('status', $old)->update(['status' => $new]);
        }

        // One audit trail for payment, return and payout decisions.
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->morphs('subject');
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('actor_role', 20)->nullable();
            $table->string('action', 50);
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30)->nullable();
            $table->bigInteger('amount_cents')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        // Double-entry ledger: each transaction's entries sum to zero.
        Schema::create('ledger_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('type', 40);
            $table->string('idempotency_key')->unique();
            $table->foreignId('order_id')->nullable()->constrained('orders')->restrictOnDelete();
            $table->foreignId('return_request_id')->nullable()->constrained('return_requests')->restrictOnDelete();
            $table->unsignedBigInteger('payout_id')->nullable()->index();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('memo')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('ledger_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ledger_transaction_id')->constrained('ledger_transactions')->restrictOnDelete();
            $table->string('account', 30);
            $table->foreignId('user_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('orders')->restrictOnDelete();
            $table->bigInteger('amount_cents');
            $table->index(['account', 'user_id']);
        });

        Schema::create('payouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payee_id')->constrained('users')->restrictOnDelete();
            $table->string('payee_role', 20);
            $table->date('period_start');
            $table->date('period_end');
            $table->bigInteger('amount_cents');
            $table->string('status', 20)->default('pending');
            $table->string('method', 30)->default('manual');
            $table->string('reference')->nullable();
            $table->text('failure_reason')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('processing_at')->nullable();
            $table->foreignId('completed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();
        });

        // A payable line (one seller's or rider's share of a settlement) can
        // be in at most one payout at a time.
        Schema::create('payout_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payout_id')->constrained('payouts')->cascadeOnDelete();
            $table->foreignId('ledger_entry_id')->unique()->constrained('ledger_entries')->restrictOnDelete();
            $table->bigInteger('amount_cents');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payout_items');
        Schema::dropIfExists('payouts');
        Schema::dropIfExists('ledger_entries');
        Schema::dropIfExists('ledger_transactions');
        Schema::dropIfExists('audit_logs');

        foreach (['info_requested', 'with_seller', 'proposed', 'escalated'] as $state) {
            DB::table('return_requests')->where('status', $state)->update(['status' => 'under_review']);
        }
        DB::table('return_requests')->where('status', 'resolved')->update(['status' => 'processing']);
        DB::table('return_requests')->where('status', 'completed')->update(['status' => 'refunded']);
        Schema::table('return_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('refund_courier_id');
            $table->dropColumn([
                'resolution_type', 'resolution_amount', 'requires_item_return', 'info_request', 'seller_note',
                'admin_approved_at', 'proposed_at', 'escalated_at', 'resolved_at', 'refund_released_at',
                'item_collected_at', 'item_received_at', 'restocked', 'replacement_sent_at', 'completed_at',
            ]);
            $table->enum('status', ['requested', 'under_review', 'processing', 'refunded', 'rejected'])->default('requested')->change();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('payment_confirmed_by');
            $table->dropConstrainedForeignId('cod_collected_by');
            $table->dropColumn(['cod_collected_at', 'paid_at', 'settled_at']);
        });
    }
};
