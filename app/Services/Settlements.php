<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\LedgerEntry;
use App\Models\LedgerTransaction;
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
 * Turns paid orders into what is owed to sellers, and records manual
 * payouts to sellers and riders. Nothing here sends money: an admin pays
 * outside the system (bank / e-wallet transfer) and records the reference.
 * Rider pay accrues separately (App\Services\RiderPay) when cash is handed in.
 *
 * Settlement of one order (centavos), once the cash is handed in, the
 * return window has passed, no return is open and the payment isn't under review:
 *
 *   seller gross   = item price after store vouchers; platform vouchers are
 *                    funded by Picksell, so the seller keeps the pre-discount price
 *   seller refund  = refunds whose recorded funder is the seller (capped at seller gross)
 *   commission     = commission_rate × (seller gross − seller refund); never on shipping
 *   withholding    = RR 16-2023, only if enabled: rate × base × (seller gross − seller refund)
 *   seller payable = seller gross − seller refund − commission − withholding
 *   platform       = cash kept − seller payable − withholding
 *                    (shipping and service fees, commission, minus platform vouchers
 *                     and platform-funded refunds)
 *
 * Refunds paid after settlement (late defect claims) are booked by
 * adjustForLateRefund(); posted settlements are never edited.
 */
class Settlements
{
    public function __construct(private Ledger $ledger) {}

    public function eligibleOrders(): Builder
    {
        return Order::whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->whereNull('settled_at')
            ->whereNull('payment_review')
            ->whereNotNull('delivered_at')
            ->where('delivered_at', '<=', now()->subDays((int) config('picksell.return_window_days')))
            ->whereDoesntHave('returnRequest', fn ($q) => $q->whereNotIn('status', ReturnRequest::CLOSED));
    }

    /** @return array<string, int> centavos */
    public function breakdown(Order $order): array
    {
        $total = $order->totalCents();
        [$sellerFunded, $platformFunded] = $this->refundsByFunder($order);
        $refunded = $sellerFunded + $platformFunded;
        $amount = Money::cents($order->amount);
        $sellerGross = $this->platformFundedDiscount($order) ? Money::cents($order->subtotal ?? $order->amount) : $amount;

        $sellerRefund = min($sellerFunded, $sellerGross);
        $base = $sellerGross - $sellerRefund;
        $commission = Money::times($base, $this->commissionRate());
        $withholding = Money::times($base, $this->withholdingRate());
        $seller = $base - $commission - $withholding;
        $kept = $total - $refunded;

        return [
            'total'           => $total,
            'refunded'        => $refunded,
            'seller_refund'   => $sellerRefund,
            'platform_refund' => $refunded - $sellerRefund,
            'seller_gross'    => $sellerGross,
            'commission'      => $commission,
            'withholding'     => $withholding,
            'seller'          => $seller,
            'platform'        => $kept - $seller - $withholding,
            'kept'            => $kept,
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
                [Ledger::PLATFORM_REVENUE, null, -$b['platform'], $order->id],
            ], ['order_id' => $order->id], $actor, "Settlement of {$order->order_number}",
                $b + ['commission_rate' => $this->commissionRate(), 'withholding_rate' => $this->withholdingRate()]);

            $order->update(['settled_at' => now()]);
            AuditLog::record($order, 'settled', null, null, null, $b['seller'], $actor);
        });
    }

    /**
     * A refund handed over after the order settled (e.g. a defect claim
     * inside the warranty period). Reverses the seller's share of a
     * seller-funded refund — including its commission and withholding at
     * the rates used at settlement — or charges it to Picksell.
     */
    public function adjustForLateRefund(Order $order, ReturnRequest $return, int $cents, ?User $actor = null): void
    {
        if (!$order->settled_at) return;

        $settlement = LedgerTransaction::where('idempotency_key', "settlement:order:{$order->id}")->firstOrFail();
        $rates = $settlement->details ?? [];
        $lines = [[Ledger::ORDER_FUNDS, null, -$cents, $order->id]];
        $details = ['funded_by' => $return->refund_funded_by, 'refund_cents' => $cents];

        if ($return->refund_funded_by === 'seller') {
            $sellerPart = min($cents, max(0, ($rates['seller_gross'] ?? 0) - ($rates['seller_refund'] ?? 0)));
            $commissionBack = Money::times($sellerPart, $rates['commission_rate'] ?? $this->commissionRate());
            $withholdingBack = Money::times($sellerPart, $rates['withholding_rate'] ?? '0');
            $lines[] = [Ledger::SELLER_PAYABLE, $order->seller_id, $sellerPart - $commissionBack - $withholdingBack, $order->id];
            $lines[] = [Ledger::WITHHOLDING_TAX, $order->seller_id, $withholdingBack, $order->id];
            $lines[] = [Ledger::PLATFORM_REVENUE, null, $cents - $sellerPart + $commissionBack, $order->id];
            $details += ['seller_part' => $sellerPart, 'commission_reversed' => $commissionBack, 'withholding_reversed' => $withholdingBack];
        } else {
            $lines[] = [Ledger::PLATFORM_REVENUE, null, $cents, $order->id];
        }

        $this->ledger->post('late_refund_adjustment', "late_refund_adjustment:return:{$return->id}", $lines,
            ['order_id' => $order->id, 'return_request_id' => $return->id], $actor, "Refund after settlement for {$order->order_number}", $details);
        AuditLog::record($order, 'late_refund_adjusted', null, null, "Return #{$return->id}, funded by {$return->refund_funded_by}", $cents, $actor);
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

    /** Ledger lines that make up what sellers and riders are owed. */
    private const PAYABLE_SOURCES = ['order_settlement', 'rider_pay_accrued', 'late_refund_adjustment'];

    /**
     * Creates one pending payout per seller/rider for their settled, not yet
     * paid lines up to the end of the period, netting any later refund
     * adjustments. Lines already in a payout are skipped; a payee whose net
     * is zero or negative gets no payout and their lines carry forward.
     */
    public function generatePayouts(CarbonImmutable $start, CarbonImmutable $end, User $admin): Collection
    {
        return DB::transaction(function () use ($start, $end, $admin) {
            $lines = LedgerEntry::whereIn('account', [Ledger::SELLER_PAYABLE, Ledger::RIDER_PAYABLE])
                ->whereNotNull('user_id')
                ->whereHas('transaction', fn ($q) => $q->whereIn('type', self::PAYABLE_SOURCES)->where('created_at', '<=', $end))
                ->whereDoesntHave('payoutItem')
                ->lockForUpdate()->get();

            return $lines->groupBy(fn ($l) => $l->account . ':' . $l->user_id)->map(function ($group) use ($start, $end, $admin) {
                $first = $group->first();
                $amount = -$group->sum('amount_cents');
                if ($amount <= 0) return null;
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
            })->filter()->values();
        });
    }

    public function approve(Payout $payout, User $admin): void
    {
        $this->movePayout($payout, ['pending'], 'approved', $admin, function (Payout $p) use ($admin) {
            abort_if($this->needsSecondAdmin($p) && $p->created_by === $admin->id, 422,
                'This payout needs approval from a different admin than the one who created it.');
            $this->ensureWithinBalance($p);
            return ['approved_by' => $admin->id, 'approved_at' => now()];
        });
    }

    /** Two-person rule: on for payouts at or above the configured threshold. */
    public function needsSecondAdmin(Payout $payout): bool
    {
        return (bool) config('picksell.finance.payout_requires_second_admin')
            && $payout->amount_cents >= Money::cents(config('picksell.finance.second_admin_threshold', '0'));
    }

    /** A payout may never exceed what the payee is currently owed. */
    private function ensureWithinBalance(Payout $p): void
    {
        $account = $p->payee_role === 'seller' ? Ledger::SELLER_PAYABLE : Ledger::RIDER_PAYABLE;
        $owed = -$this->ledger->balance($account, $p->payee_id);
        abort_if($p->amount_cents > $owed, 422, 'This payout is more than the payee is currently owed (' . Money::format($owed) . '). Cancel it and create a new one.');
    }

    public function markProcessing(Payout $payout, User $admin): void
    {
        $this->movePayout($payout, ['approved'], 'processing', $admin, fn () => ['processing_at' => now()]);
    }

    /**
     * Records a transfer the admin actually made outside Picksell: its bank /
     * e-wallet reference and the date the money left. Never before that.
     */
    public function complete(Payout $payout, User $admin, string $reference, string $disbursedOn): void
    {
        abort_if(CarbonImmutable::parse($disbursedOn)->isFuture(), 422, 'The disbursement date can’t be in the future.');
        $this->movePayout($payout, ['approved', 'processing'], 'completed', $admin, function (Payout $p) use ($admin, $reference, $disbursedOn) {
            $amount = (int) $p->items()->sum('amount_cents');
            abort_if($amount !== $p->amount_cents, 422, 'This payout no longer matches its items and needs review.');
            $this->ensureWithinBalance($p);
            $account = $p->payee_role === 'seller' ? Ledger::SELLER_PAYABLE : Ledger::RIDER_PAYABLE;
            $this->ledger->post('payout', "payout:{$p->id}", [
                [$account, $p->payee_id, $amount],
                [Ledger::PLATFORM_CASH, null, -$amount],
            ], ['payout_id' => $p->id], $admin, "Payout #{$p->id}, reference {$reference}",
                ['reference' => $reference, 'disbursed_on' => $disbursedOn]);
            return ['reference' => $reference, 'disbursed_on' => $disbursedOn, 'completed_by' => $admin->id, 'completed_at' => now()];
        }, "Reference {$reference}, disbursed {$disbursedOn}");
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
            'returns_awaiting_admin' => ReturnRequest::whereIn('status', [ReturnRequest::REQUESTED, ReturnRequest::ESCALATED])->count(),
            'undetermined_liability' => ReturnRequest::where('liable_party', 'undetermined')->whereNotIn('status', ReturnRequest::CLOSED)->count(),
            'legacy_orders'     => Order::where('status', 'completed')->where('payment_status', 'unpaid')->whereNull('cod_collected_by')
                ->whereNull('payment_backfilled_at')->with('returnRequest')->orderBy('delivered_at')->get(),
            'payouts_pending'   => Payout::whereIn('status', Payout::ACTIVE)->count(),
            'discrepancies'     => [
                'delivered_without_collection' => Order::where('status', 'completed')->where('payment_status', 'unpaid')->whereNull('payment_review')->pluck('order_number')->all(),
                'settled_with_open_funds'      => Order::whereIn('id', $settledMismatch)->pluck('order_number')->all(),
                'ledger_out_of_balance'        => (int) LedgerEntry::sum('amount_cents'),
            ],
            'rider_pay_status'     => app(RiderPay::class)->status(),
            'rider_pay_rates'      => app(RiderPay::class)->rates(),
            'withholding_enabled'  => (bool) config('picksell.finance.withholding.enabled'),
        ];
    }

    // ── Rules ────────────────────────────────────────────────────────────

    /** @return array{0: int, 1: int} refunds handed to the buyer, funded by the seller / by Picksell */
    private function refundsByFunder(Order $order): array
    {
        $seller = $platform = 0;
        foreach (LedgerTransaction::with('entries', 'returnRequest')->where('order_id', $order->id)->where('type', 'refund_paid')->get() as $t) {
            $cents = (int) $t->entries->where('account', Ledger::ORDER_FUNDS)->sum('amount_cents');
            ($t->returnRequest?->refund_funded_by === 'seller') ? $seller += $cents : $platform += $cents;
        }
        return [$seller, $platform];
    }

    private function commissionRate(): string
    {
        return (string) BigDecimal::of((string) config('picksell.commission_rate'));
    }

    /** RR 16-2023 effective rate (rate × base), or "0" while withholding is disabled. */
    private function withholdingRate(): string
    {
        if (!config('picksell.finance.withholding.enabled')) return '0';
        return (string) BigDecimal::of(config('picksell.finance.withholding.rate'))->multipliedBy(config('picksell.finance.withholding.base'));
    }

    private function platformFundedDiscount(Order $order): bool
    {
        if (!$order->voucher_code || Money::cents($order->discount) <= 0) return false;
        $scope = Voucher::where('code', $order->voucher_code)->value('scope');
        return $scope === 'platform' && config('picksell.finance.platform_voucher_funded_by') === 'platform';
    }

}
