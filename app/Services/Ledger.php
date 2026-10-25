<?php

namespace App\Services;

use App\Models\LedgerEntry;
use App\Models\LedgerTransaction;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * Double-entry money ledger in centavos (debit +, credit −). Accounts:
 *
 *   rider_cash       cash a rider is physically holding (per rider)
 *   platform_cash    cash handed in to the sorting center / Picksell
 *   order_funds      buyer money received for an order, not yet allocated (per order)
 *   seller_payable   owed to a seller (credit balance, per seller)
 *   rider_payable    owed to a rider for deliveries (credit balance, per rider)
 *   withholding_tax  tax withheld from sellers, owed to the BIR
 *   platform_revenue commission, shipping and fees kept by Picksell
 *
 * Every posting has an idempotency key, so the same collection, refund,
 * settlement or payout can never be recorded twice.
 */
class Ledger
{
    public const RIDER_CASH       = 'rider_cash';
    public const PLATFORM_CASH    = 'platform_cash';
    public const ORDER_FUNDS      = 'order_funds';
    public const SELLER_PAYABLE   = 'seller_payable';
    public const RIDER_PAYABLE    = 'rider_payable';
    public const WITHHOLDING_TAX  = 'withholding_tax';
    public const PLATFORM_REVENUE = 'platform_revenue';

    /**
     * @param  array<int, array{0: string, 1: ?int, 2: int, 3?: ?int}>  $lines  [account, user_id, cents, order_id]
     * @param  array  $links  order_id / return_request_id / payout_id
     */
    public function post(string $type, string $key, array $lines, array $links = [], ?User $actor = null, ?string $memo = null): LedgerTransaction
    {
        $lines = array_values(array_filter($lines, fn ($l) => $l[2] !== 0));
        if (!$lines || array_sum(array_column($lines, 2)) !== 0) {
            throw new LogicException("Ledger posting '{$key}' does not balance.");
        }
        if (LedgerTransaction::where('idempotency_key', $key)->exists()) {
            throw new DuplicatePosting($key);
        }

        try {
            return DB::transaction(function () use ($type, $key, $lines, $links, $actor, $memo) {
                $transaction = LedgerTransaction::create($links + [
                    'type'            => $type,
                    'idempotency_key' => $key,
                    'actor_id'        => ($actor ?? auth()->user())?->id,
                    'memo'            => $memo,
                ]);
                foreach ($lines as $line) {
                    [$account, $userId, $cents, $orderId] = $line + [3 => null];
                    $transaction->entries()->create([
                        'account' => $account, 'user_id' => $userId, 'order_id' => $orderId, 'amount_cents' => $cents,
                    ]);
                }
                return $transaction;
            });
        } catch (UniqueConstraintViolationException) {
            throw new DuplicatePosting($key);
        }
    }

    public function posted(string $key): bool
    {
        return LedgerTransaction::where('idempotency_key', $key)->exists();
    }

    /** Signed balance of an account, optionally for one user and/or order. */
    public function balance(string $account, ?int $userId = null, ?int $orderId = null): int
    {
        return (int) LedgerEntry::where('account', $account)
            ->when($userId !== null, fn ($q) => $q->where('user_id', $userId))
            ->when($orderId !== null, fn ($q) => $q->where('order_id', $orderId))
            ->sum('amount_cents');
    }

    /** Balance per user for an account: [user_id => cents], non-zero only. */
    public function balancesByUser(string $account): array
    {
        return LedgerEntry::where('account', $account)->whereNotNull('user_id')
            ->groupBy('user_id')->selectRaw('user_id, SUM(amount_cents) as balance')
            ->pluck('balance', 'user_id')->map(fn ($v) => (int) $v)->filter()->all();
    }
}
