<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Payout;
use App\Models\ReturnRequest;
use App\Models\User;
use App\Models\Voucher;
use App\Support\Money;
use Brick\Math\BigDecimal;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Turns paid orders into what is owed to sellers and riders, and records
 * manual payouts. Nothing here sends money: an admin pays outside the
 * system (bank / e-wallet transfer) and records the reference.
 *
 * Settlement of one order (centavos), once the cash is handed in, the
 * return window has passed and no return is open:
 *
 *   seller gross   = item price before platform vouchers (store vouchers are seller-funded)
 *   refund (items) = refunds handed to the buyer, charged to the seller first
 *   commission     = commission_rate × (seller gross − item refund)
 *   withholding    = RR 16-2023, if enabled: rate × base × (seller gross − item refund)
 *   seller payable = seller gross − item refund − commission − withholding
 *   rider pay      = rider_fee_per_delivery, if configured
 *   platform       = cash kept − seller payable − withholding − rider pay
 *                    (shipping and service fees, commission, minus platform vouchers)
 */
class Settlements
{
    public function __construct(private Ledger $ledger) {}

    public function eligibleOrders(): Builder
    {
        return Order::whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->whereNull('settled_at')
            ->whereNotNull('delivered_at')
            ->where('delivered_at', '<=', now()->subDays((int) config('picksell.return_window_days')))
            ->whereDoesntHave('returnRequest', fn ($q) => $q->whereNotIn('status', ReturnRequest::CLOSED));
    }

    /** @return array<string, int> centavos */
    public function breakdown(Order $order): array
    {
        $total = $order->totalCents();
        $refunded = $this->refundedCents($order);
        $amount = Money::cents($order->amount);
        $sellerGross = $this->platformFundedDiscount($order) ? Money::cents($order->subtotal ?? $order->amount) : $amount;

        $itemRefund = min($refunded, $sellerGross);
        $base = $sellerGross - $itemRefund;
        $commission = Money::times($base, (string) config('picksell.commission_rate'));
        $withholding = $this->withholding($base);
        $seller = $base - $commission - $withholding;
        $riderFee = $this->riderFee($order);
        $kept = $total - $refunded;

        return [
            'total'        => $total,
            'refunded'     => $refunded,
            'seller_gross' => $sellerGross,
            'item_refund'  => $itemRefund,
            'commission'   => $commission,
            'withholding'  => $withholding,
            'seller'       => $seller,
            'rider'        => $riderFee,
            'platform'     => $kept - $seller - $withholding - $riderFee,
            'kept'         => $kept,
        ];
    }

    public function settle(Order $order, ?User $actor = null): void
    {
        DB::transaction(function () use ($order, $actor) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            abort_unless($this->eligibleOrders()->whereKey($order->id)->exists(), 422, "Order {$order->order_number} is not ready to settle.");

            $b = $this->breakdown($order);
            // The buyer's cash for this order must be in the ledger, unallocated.
            $unallocated = -$this->ledger->balance(Ledger::ORDER_FUNDS, null, $order->id);
            abort_if($unallocated !== $b['kept'], 422, "Order {$order->order_number} has a cash discrepancy and needs review.");

            $this->ledger->post('order_settlement', "settlement:order:{$order->id}", [
                [Ledger::ORDER_FUNDS, null, $b['kept'], $order->id],
                [Ledger::SELLER_PAYABLE, $order->seller_id, -$b['seller'], $order->id],
                [Ledger::WITHHOLDING_TAX, $order->seller_id, -$b['withholding'], $order->id],
                [Ledger::RIDER_PAYABLE, $order->cod_collected_by ?? $order->courier_id, -$b['rider'], $order->id],
                [Ledger::PLATFORM_REVENUE, null, -$b['platform'], $order->id],
            ], ['order_id' => $order->id], $actor, "Settlement of {$order->order_number}");

            $order->update(['settled_at' => now()]);
            AuditLog::record($order, 'settled', null, null, null, $b['seller'], $actor);
        });
    }

    /** Settles every eligible order; safe to run repeatedly. */
    public function settleEligible(?User $actor = null): int
    {
        $count = 0;
        foreach ($this->eligibleOrders()->pluck('id') as $id) {
            try {
                $this->settle(Order::find($id), $actor);
                $count++;
            } catch (DuplicatePosting) {
                // Settled by a concurrent run.
            }
        }
        return $count;
    }

    // ── Payouts ──────────────────────────────────────────────────────────

    /** [start, end] of the last full payout period before today. */
    public function lastPeriod(): array
    {
        $today = CarbonImmutable::today();
        return config('picksell.finance.payout_period') === 'daily'
            ? [$today->subDay(), $today->subDay()->endOfDay()]
            : [$today->startOfWeek()->subWeek(), $today->startOfWeek()->subWeek()->endOfWeek()];
    }

    /**
     * Creates one pending payout per seller/rider for their settled, not yet
     * paid shares up to the end of the period. Shares already in an active or
     * completed payout are skipped.
     */
    public function generatePayouts(CarbonImmutable $start, CarbonImmutable $end, User $admin): Collection
    {
        return DB::transaction(function () use ($start, $end, $admin) {
            $lines = LedgerEntry::whereIn('account', [Ledger::SELLER_PAYABLE, Ledger::RIDER_PAYABLE])
                ->where('amount_cents', '<', 0)->whereNotNull('user_id')
                ->whereHas('transaction', fn ($q) => $q->where('type', 'order_settlement')->where('created_at', '<=', $end))
                ->whereDoesntHave('payoutItem')
                ->lockForUpdate()->get();

            return $lines->groupBy(fn ($l) => $l->account . ':' . $l->user_id)->map(function ($group) use ($start, $end, $admin) {
                $first = $group->first();
                $amount = -$group->sum('amount_cents');
                $payout = Payout::create([
                    'payee_id'     => $first->user_id,
                    'payee_role'   => $first->account === Ledger::SELLER_PAYABLE ? 'seller' : 'courier',
                    'period_start' => $start->toDateString(),
                    'period_end'   => $end->toDateString(),
                    'amount_cents' => $amount,
                    'status'       => 'pending',
                    'created_by'   => $admin->id,
                ]);
                foreach ($group as $line) {
                    $payout->items()->create(['ledger_entry_id' => $line->id, 'amount_cents' => -$line->amount_cents]);
                }
                AuditLog::record($payout, 'created', null, 'pending', null, $amount, $admin);
                return $payout;
            })->values();
        });
    }

    public function approve(Payout $payout, User $admin): void
    {
        $this->movePayout($payout, ['pending'], 'approved', $admin, function (Payout $p) use ($admin) {
            abort_if(config('picksell.finance.payout_requires_second_admin') && $p->created_by === $admin->id, 422,
                'A different admin must approve this payout.');
            return ['approved_by' => $admin->id, 'approved_at' => now()];
        });
    }

    public function markProcessing(Payout $payout, User $admin): void
    {
        $this->movePayout($payout, ['approved'], 'processing', $admin, fn () => ['processing_at' => now()]);
    }

    /** Records a transfer the admin actually made, with its bank / e-wallet reference. */
    public function complete(Payout $payout, User $admin, string $reference): void
    {
        $this->movePayout($payout, ['approved', 'processing'], 'completed', $admin, function (Payout $p) use ($admin, $reference) {
            $amount = (int) $p->items()->sum('amount_cents');
            abort_if($amount !== $p->amount_cents, 422, 'This payout no longer matches its items and needs review.');
            $account = $p->payee_role === 'seller' ? Ledger::SELLER_PAYABLE : Ledger::RIDER_PAYABLE;
            $this->ledger->post('payout', "payout:{$p->id}", [
                [$account, $p->payee_id, $amount],
                [Ledger::PLATFORM_CASH, null, -$amount],
            ], ['payout_id' => $p->id], $admin, "Payout #{$p->id}, reference {$reference}");
            return ['reference' => $reference, 'completed_by' => $admin->id, 'completed_at' => now()];
        }, $reference);
    }

    /** The transfer bounced or couldn't be made; the shares become payable again. */
    public function fail(Payout $payout, User $admin, string $reason): void
    {
        $this->movePayout($payout, ['approved', 'processing'], 'failed', $admin, function (Payout $p) use ($reason) {
            $p->items()->delete();
            return ['failure_reason' => $reason, 'failed_at' => now()];
        }, $reason);
    }

    public function cancel(Payout $payout, User $admin, string $reason): void
    {
        $this->movePayout($payout, ['pending', 'approved'], 'cancelled', $admin, function (Payout $p) use ($reason) {
            $p->items()->delete();
            return ['failure_reason' => $reason, 'cancelled_at' => now()];
        }, $reason);
    }

    private function movePayout(Payout $payout, array $from, string $to, User $admin, \Closure $changes, ?string $note = null): void
    {
        DB::transaction(function () use ($payout, $from, $to, $admin, $changes, $note) {
            $p = Payout::lockForUpdate()->findOrFail($payout->id);
            abort_unless(in_array($p->status, $from, true), 422, "This payout is {$p->status} and can't be changed that way.");
            $previous = $p->status;
            $p->update(['status' => $to] + $changes($p));
            AuditLog::record($p, $to, $previous, $to, $note, $p->amount_cents, $admin);
            $payout->setRawAttributes($p->getAttributes(), true);
        });
    }

    // ── Reconciliation ───────────────────────────────────────────────────

    public function reconciliation(): array
    {
        $users = fn (array $balances) => User::whereIn('id', array_keys($balances))->get()->keyBy('id');
        $riderCash = $this->ledger->balancesByUser(Ledger::RIDER_CASH);
        $sellerOwed = array_map(fn ($c) => -$c, $this->ledger->balancesByUser(Ledger::SELLER_PAYABLE));
        $riderOwed = array_map(fn ($c) => -$c, $this->ledger->balancesByUser(Ledger::RIDER_PAYABLE));
        $inPayouts = Payout::whereIn('status', Payout::ACTIVE)->groupBy('payee_id')->selectRaw('payee_id, SUM(amount_cents) as c')->pluck('c', 'payee_id');

        $collected = Order::where('payment_status', 'collected')->get();
        $settledMismatch = Order::whereNotNull('settled_at')->pluck('id')
            ->filter(fn ($id) => $this->ledger->balance(Ledger::ORDER_FUNDS, null, $id) !== 0)->values();

        return [
            'rider_cash'        => $riderCash,
            'platform_cash'     => $this->ledger->balance(Ledger::PLATFORM_CASH),
            'seller_owed'       => $sellerOwed,
            'rider_owed'        => $riderOwed,
            'in_payouts'        => $inPayouts->map(fn ($v) => (int) $v)->all(),
            'withholding_owed'  => -$this->ledger->balance(Ledger::WITHHOLDING_TAX),
            'platform_revenue'  => -$this->ledger->balance(Ledger::PLATFORM_REVENUE),
            'users'             => $users($riderCash + $sellerOwed + $riderOwed),
            'collected_orders'  => $collected,
            'collected_cents'   => $collected->sum(fn ($o) => $o->totalCents()),
            'eligible_count'    => $this->eligibleOrders()->count(),
            'waiting_window'    => Order::whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->whereNull('settled_at')->count() - $this->eligibleOrders()->count(),
            'refunds_pending'   => ReturnRequest::where('status', ReturnRequest::RESOLVED)->whereNull('refunded_at')->where('resolution_amount', '>', 0)->with('order', 'refundCourier')->get(),
            'discrepancies'     => [
                'delivered_without_collection' => Order::where('status', 'completed')->where('payment_status', 'unpaid')->pluck('order_number')->all(),
                'settled_with_open_funds'      => Order::whereIn('id', $settledMismatch)->pluck('order_number')->all(),
                'ledger_out_of_balance'        => (int) LedgerEntry::sum('amount_cents'),
            ],
            'rider_pay_configured' => config('picksell.finance.rider_fee_per_delivery') !== null,
            'withholding_enabled'  => (bool) config('picksell.finance.withholding.enabled'),
        ];
    }

    // ── Rules ────────────────────────────────────────────────────────────

    private function refundedCents(Order $order): int
    {
        return (int) LedgerEntry::where('order_id', $order->id)->where('account', Ledger::ORDER_FUNDS)
            ->whereHas('transaction', fn ($q) => $q->where('type', 'refund_paid'))->sum('amount_cents');
    }

    private function platformFundedDiscount(Order $order): bool
    {
        if (!$order->voucher_code || Money::cents($order->discount) <= 0) return false;
        $scope = Voucher::where('code', $order->voucher_code)->value('scope');
        return $scope === 'platform' && config('picksell.finance.platform_voucher_funded_by') === 'platform';
    }

    private function withholding(int $base): int
    {
        if (!config('picksell.finance.withholding.enabled')) return 0;
        $rate = BigDecimal::of(config('picksell.finance.withholding.rate'))->multipliedBy(config('picksell.finance.withholding.base'));
        return Money::times($base, (string) $rate);
    }

    private function riderFee(Order $order): int
    {
        $fee = config('picksell.finance.rider_fee_per_delivery');
        return $fee === null || $fee === '' || !($order->cod_collected_by ?? $order->courier_id) ? 0 : Money::cents($fee);
    }
}
