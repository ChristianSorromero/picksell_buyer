# Payments, returns and payouts

How money moves through Picksell, and the rules behind it. Code references
are relative to the repository root.

## 1. Payments: Cash on Delivery only

No payment gateway is integrated, so Cash on Delivery (COD) is the only
method. GCash, Maya and cards are not offered anywhere, and the API and
website reject them even if a client submits them (`config/picksell.php`
`payment_methods`).

An order's `payment_status` moves through these states. Each step is a
separate, audited event, and none happens automatically:

| Step | Who | `payment_status` | Recorded as |
|---|---|---|---|
| Order placed | Buyer | `unpaid` | — |
| Delivered, cash collected | The assigned rider, entering the exact amount | `collected` | `cod_collected` ledger transaction |
| Cash handed in and counted | Sorting-center staff or admin | `paid` | `cod_remitted` ledger transaction |
| Refund handed back | Rider | `partially_refunded` / `refunded` | `refund_paid` ledger transaction |

Safeguards:
- Delivery and cash collection happen in the same step. The rider must
  enter exactly the order total.
- Only the rider assigned to the order can record it.
- Each step can be recorded once (unique idempotency key per order).

Code: `App\Services\CodPayments`.

## 2. Returns and refunds: admin first, then the seller

```
requested ─admin─▶ info_requested ─buyer replies─▶ requested
    ├─admin rejects─▶ rejected
    └─admin approves─▶ with_seller ─seller proposes─▶ proposed ─buyer accepts─▶ resolved ─all steps done─▶ completed
                            └─seller declines─┐            └─buyer declines─┐
                                              ▼                             ▼
                                          escalated ─admin decides─▶ resolved | rejected
```

- **Admin reviews first.** Sellers never see a request before admin
  approves it. Admin can ask the buyer for more information, approve the
  request, or reject it with a reason.
- **The seller proposes, and the buyer accepts or declines** (in the app).
  Possible outcomes:
  - return the item for a refund (any amount up to what was paid)
  - full refund, buyer keeps the item
  - partial refund, buyer keeps the item
  - replacement
- **Disagreements go back to admin.** If the seller declines, or the buyer
  declines the proposal, admin records the final outcome.
- **Refunds are paid in cash, the reverse of delivery:**
  1. Sorting-center staff release the approved amount to a rider (only once
     the buyer's original cash was handed in).
  2. The rider hands exactly that amount to the buyer, collecting the item
     if it must come back.
  3. If the rider can't deliver it, staff record the cash as brought back,
     and it can be released again.
- **Returned items are restocked only when the seller confirms** they have
  the item and it can be sold again.
- **A case is completed only when every step is done:** the refund is
  handed over, the item is received if it had to come back, and the
  replacement is sent if that was the outcome.
- **Limits:** one return per order, only within `return_window_days` of
  delivery. A refund can't exceed what the buyer paid for the order.
- **Audit:** every decision and step is written to `audit_logs`, with
  actor, role, time, note and amount.

Code: `App\Services\ReturnWorkflow`. The buyer app receives the same five
`status` values it always has, plus `stage`, `stage_label`, `awaiting`
and `proposal`.

## 3. Settlement and payouts

### Ledger
All money is recorded in a double-entry ledger in integer centavos
(`ledger_transactions`, `ledger_entries`; `App\Services\Ledger`):
- Every transaction balances to zero.
- Every transaction has a unique idempotency key.
- Records can't be edited or deleted; corrections are made with
  reversal entries.

| Account | Meaning |
|---|---|
| `rider_cash` | Cash a rider is physically holding |
| `platform_cash` | Cash handed in to the sorting center / Picksell |
| `order_funds` | Buyer money received for an order, not yet allocated |
| `seller_payable` | Owed to a seller |
| `rider_payable` | Owed to a rider |
| `withholding_tax` | Withheld from sellers, owed to the BIR |
| `platform_revenue` | Commission, shipping and fees kept by Picksell |

### When an order settles
An order settles only when all three hold:
1. its cash is handed in (`paid`)
2. the return window has passed
3. no return on it is still open

Delivery alone never settles an order. Settlement runs daily
(`php artisan picksell:settle-orders`, scheduled for 02:00), or from
Admin → Finance.

### What each party gets (per order)

| Component | Rule |
|---|---|
| Seller gross | Item price after store vouchers. Platform vouchers are funded by Picksell: the seller is credited the pre-discount price. |
| Item refund | Refunds handed to the buyer, charged to the seller's items first |
| Commission | `commission_rate` × (seller gross − item refund) |
| Withholding | Off by default. When enabled: 1% × ½ × (seller gross − item refund), per RR 16-2023 |
| Seller payable | Seller gross − item refund − commission − withholding |
| Rider pay | `rider_fee_per_delivery` per delivered order. Not set = none accrued. |
| Platform | Cash kept − seller payable − withholding − rider pay |

### Payouts
Payouts are always manual. Nothing is transferred automatically.
1. Admin creates pending payouts for a period. This includes every
   settled, unpaid seller and rider share. Each share can be in only one
   payout at a time.
2. Admin approves the payout. Optionally, a second admin can be required
   to approve it.
3. Admin makes the transfer outside Picksell (bank or e-wallet).
4. Admin records the transfer reference, which completes the payout.

A failed or cancelled payout releases its shares to be paid again.
Reconciliation (Admin → Finance) shows:
- cash still with riders, and cash at the sorting center
- what is owed to sellers and riders, and what is in open payouts
- delivered orders with no recorded collection
- approved refunds not yet handed over
- a check that the ledger balances

Code: `App\Services\Settlements`.

## 4. Research behind the defaults

**Legal requirements**
- **Withholding tax on remittances to online sellers.** BIR RR 16-2023
  imposes 1% creditable withholding on one-half of the gross remittances
  e-marketplace operators make to sellers.
  - The base excludes sales returns, discounts, separately billed delivery
    fees and VAT.
  - Sellers under ₱500,000 a year (across all platforms) are exempt if
    they file a sworn declaration.
  - It took effect January 2024. RMC 8-2024 clarifies the threshold and
    the sworn-declaration rules.
  - *Effect on the design:* withholding is computed only on the seller's
    item amount after refunds and discounts. It is off until per-seller
    exemptions are tracked.

  Sources:
  [Baker McKenzie](https://insightplus.bakermckenzie.com/bm/tax/philippines-bureau-of-internal-revenue-issues-regulations-on-withholding-tax-on-remittances-by-online-platforms-to-online-sellersmerchants),
  [Grant Thornton](https://www.grantthornton.com.ph/insights/articles-and-updates1/tax-notes/online-sellers-subject-to-1-expanded-withholding-tax/),
  [PNA](https://alpha.pna.gov.ph/articles/1216099),
  [Grant Thornton on RMC 8-2024](https://www.grantthornton.com.ph/insights/articles-and-updates1/lets-talk-tax/withholding-tax-rules-on-digital-commerce/),
  [RMC 8-2024 text](https://batasnatin.com/laws/rmc-no-8-2024-clarifying-the-provisions-of-revenue-regulations-no-16-2023-im).
- **Internet Transactions Act (RA 11967, 2023).**
  - E-marketplaces must vet merchants and keep their identity records.
  - Buyers' remedies of repair, replacement or refund run against the
    seller, with goods returned at no cost to the buyer unless agreed
    otherwise.
  - *Effect on the design:* the seller resolves the case and the platform
    oversees it. The outcomes on offer are the remedies the Act names.

  Sources:
  [Diokno](https://cheldiokno.com/article/ano-ang-mga-proteksiyong-hatid-ng-internet-transactions-act/),
  [NDV Law](https://ndvlaw.com/how-do-online-buyers-get-refunds-and-returns/).
- **Rider pay (DOLE Labor Advisory No. 14, 2021).**
  - Riders engaged as independent contractors must receive fair
    compensation not lower than the prevailing minimum wage, plus
    SSS/PhilHealth/Pag-IBIG registration.
  - Whether a rider is an employee depends on the four-fold test.
  - *Effect on the design:* no rider rate is invented. It must be set
    deliberately, with the classification decided by counsel.

  Sources:
  [Conventus Law](https://conventuslaw.com/report/philippines-labor-advisory-on-working-conditions-of-delivery-riders-in-food-delivery-and-courier-activities/),
  [Mondaq](https://webiis10.mondaq.com/employee-rights-labour-relations/1270430/labor-advisory-on-working-conditions-of-delivery-riders-in-food-delivery-and-courier-activities).

**Industry practice** (recommendations, not legal requirements; mostly
secondary sources)
- **Marketplaces hold funds until delivery is confirmed, then pay out in
  weekly statements**, net of fees and returns. This is described for
  Shopee (escrow) and Lazada (Mon–Sun cycles, paid a few business days
  later).
  - *Effect on the design:* settlement waits for confirmed cash and the
    return window; payouts default to weekly.

  Sources:
  [Prosperna](https://www.prosperna.com/blog/shopee-lazada-payout-schedule-philippines-guide),
  [Ginee](https://ginee.com/ph/insights/how-lazada-pay-seller),
  [Lazada help](https://community.lazada.com.ph/article/payout-faqs-for-corporate-sellers-1296100-hc).
- **COD remittance is a separate, reconciled step.** Couriers remit COD
  only after the buyer pays and delivery completes, net of handling fees,
  on an agreed schedule. A delivered order does not prove the cash has
  been remitted.
  - *Effect on the design:* `collected` and `paid` are separate states,
    and reconciliation lists cash still with riders.

  Sources:
  [Ninja Van COD](https://www.ninjavan.co/en-ph/support/shipper-support/billing-and-invoicing/cash-on-delivery-cod),
  [BigSeller](https://www.bigseller.pro/blog/articleDetails/4890/manage-cod-orders-fulfillment-returns-philippines.htm).

## 5. Assumptions and decisions needing approval

| Setting | Default | Approval needed |
|---|---|---|
| `commission_rate` | 0.10 (already in the project) | Confirm the rate, and whether it applies to shipping. Currently items only. |
| `finance.rider_fee_per_delivery` | Not set: no rider pay accrued | Set the rate and decide rider classification (DOLE LA 14-2021). |
| `finance.withholding.enabled` | Off | Turn on only with per-seller sworn-declaration and threshold tracking. Confirm with an accountant. |
| `finance.platform_voucher_funded_by` | `platform` | Confirm Picksell funds its own vouchers. |
| `finance.payout_period` | Weekly (Mon–Sun) | Confirm the cycle and payout day. |
| `finance.payout_requires_second_admin` | Off | Recommended on once there are two finance admins. |
| `return_window_days` | 7 (already in the project) | Also the settlement hold. Confirm. |
| Refund timing | Rider hands over the refund and collects the item on the same visit | Alternative: refund only after the seller inspects the item. |
| Who bears refunds | Seller's items first, then Picksell for shipping/fees | Confirm, especially for courier-caused damage. |
| Older orders | Delivered before COD tracking: no collection record; can't be refunded or settled | Decide a one-time backfill (admin records the cash already received). |

Not covered: BIR Form 2307 certificates, official receipts or invoices,
and automated bank or e-wallet disbursement.
