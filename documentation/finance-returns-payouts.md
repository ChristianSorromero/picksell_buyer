# Payments, returns, refunds and payouts

How money and returns move through Picksell, as implemented. Code paths are
relative to the repository root. Policies marked **provisional** need
business approval before production; legal points are summaries of the
cited sources, not legal advice.

## 1. Payments: Cash on Delivery only

No payment gateway is integrated, so Cash on Delivery (COD) is the only
payment method. GCash, Maya, cards and bank transfers are not offered
anywhere. The app API and the website reject them even if a client sends
them (`config/picksell.php` → `payment_methods`). Approved refunds are also
cash only.

An order goes through four separate events:

| Event | Who may record it | `payment_status` | Ledger |
|---|---|---|---|
| Order placed | Buyer | `unpaid` | — |
| Delivered + cash collected | Only the rider assigned to the order, entering exactly the order total, with proof of delivery (recipient's name, optional photo) | `collected` | `cod_collected`: rider cash +, order funds − |
| Cash handed in | Sorting-center staff or an admin, after counting it | `paid` | `cod_remitted`: rider cash −, platform cash + |
| Refund handed over | The rider the refund cash was released to | `partially_refunded` / `refunded` | `refund_paid` |

- **The amount due** is the order's `total`: item price after discounts and
  vouchers, plus shipping and service fees. The rider must collect exactly
  this. Any other amount is refused and nothing is recorded.
- **Delivery alone never makes an order `paid`.** It also never settles one
  (section 3).
- **Duplicate safety:** each event can be recorded once. The order row is
  locked, the starting state is checked, and the ledger enforces a unique
  idempotency key.
- **Audit:** every event writes an `audit_logs` row with actor, role, time,
  amount and note.

Code: `App\Services\CodPayments`, `App\Services\Deliveries`.

## 2. Deliveries

- **Proof of delivery:** a delivered attempt stores the recipient's name and
  an optional photo in `delivery_attempts`, separate from the ledger. Photos
  are private: admins and sorting-center staff only.
- **Failed attempts:** the rider records a reason from
  `picksell.delivery.failed_reasons`. The buyer sees "Delivery attempt
  failed". The parcel can be set out again, up to `max_attempts` (default 3).
- **Return to sender:** after failed attempts, sorting-center staff or an
  admin send the parcel back. When the seller confirms they have it, the
  order closes as "Returned to seller" and the seller decides whether to
  restock. No money moves, and the buyer is not charged.

## 3. Returns and refunds

### Workflow (admin first)
```
requested ─admin─▶ info_requested ─buyer replies─▶ requested
    ├─admin rejects─▶ rejected
    └─admin approves (records who is responsible)─▶ with_seller
          ─seller proposes─▶ proposed ─buyer accepts─▶ resolved ─all steps done─▶ completed
          └─seller declines──▶ escalated ◀──buyer declines─┘
                                   └─admin decides─▶ resolved | rejected
```
- Sellers never see a case before admin approves it.
- Every step is audited with actor, role, time, note and amount.
- The buyer app keeps its five legacy `status` values. It also receives
  `stage`, `stage_label`, `awaiting`, `info_request` and `proposal`.

### Who can request, and until when (provisional)
- **Change-of-mind returns:** within `return_window_days` (7) of delivery.
- **Defect claims** (damaged/defective, wrong item, not as described,
  missing parts): within `returns.defect_claim_days` (60).
- The DTI treats sellers' warranty duties (repair, replacement, refund) as
  running beyond a short return window. It says "no return, no exchange"
  and "no video, no refund" policies are deceptive. So evidence photos are
  optional, and defect claims aren't cut off at 7 days.
- 60 days is an operational default, **not a legal limit**. Confirm it with
  counsel.

### Outcomes
- **Return the item for a refund:** up to what was paid.
- **Full refund, buyer keeps the item:** the full order total.
- **Partial refund, buyer keeps the item:** less than the total.
- **Replacement:** no money moves; the old item comes back.

A refund can never exceed what the buyer paid for the order.

### When the refund cash goes out (case-based timing)

| Case | Timing | Rule |
|---|---|---|
| Item comes back (ordinary return) | **After inspection** (default) | A rider picks the item up, with no cash on pickup. The seller confirms receipt and records inspection passed or failed. Only after it passes can the sorting center release the refund. A failed inspection goes to admin. |
| Verified damaged, wrong or missing item | **On pickup** (expedited) | Only an admin can expedite, with a written reason (audited). The rider collects the item and hands over the refund on the same visit. |
| Buyer keeps the item (full or partial refund) | Right away | Released once responsibility is decided. |
| Cancelled before dispatch | No refund | No cash was collected, so nothing is refunded. |
| Failed delivery | No refund | No cash was collected; the parcel returns to the seller. |
| Disputed hand-over | — | The rider brings the cash back. Staff record it as returned and can release it again later. The refund is only marked paid when a hand-over is recorded. |

Refund cash is never released while:
- responsibility is undetermined
- the buyer's original cash hasn't been handed in
- the order's payment is under legacy review

The Cash Desk shows the exact reason (`ReturnRequest::refundBlocker()`).

### Responsibility and who funds the refund (provisional defaults)

| Scenario | Presumed responsible | Refund funded by | Notes |
|---|---|---|---|
| Wrong, defective, not-as-described, missing parts | Seller | Seller | Presumption only; admin confirms on approval. |
| Courier damaged or lost the item | Logistics | Picksell | Recovery from logistics is handled separately under the logistics agreement. |
| Buyer changed their mind | Buyer | Seller | Only a refund the seller agreed to. The DTI says change of mind isn't covered by warranty. |
| Platform error | Picksell | Picksell | Where substantiated. |
| Unclear or disputed | Undetermined | — | Refund blocked until admin decides with evidence. |

- Admin records the responsible party and a written basis on approval or
  decision, and can change it until the order settles. Every change is
  audited.
- **The rider who hands over refund cash only holds it and is never charged
  for it.** Cash custody (`rider_cash`), refund execution (`refund_paid`)
  and who bears the cost (funding at settlement) are separate records.
- A refund is deducted from a seller only when the seller is the recorded
  funder.

### Stock
- Returned or undelivered items go back into stock **only** when the seller
  confirms receipt, records a passed inspection, and chooses to restock.

Code: `App\Services\ReturnWorkflow`, `App\Models\ReturnRequest`.

## 4. Ledger, settlement and payouts

### Ledger
All money is recorded in a double-entry ledger in integer centavos
(`ledger_transactions`, `ledger_entries`; `App\Services\Ledger`):
- Every transaction balances to zero.
- Every transaction has a unique idempotency key, and records how its
  amount was calculated (`details`).
- Records can't be edited or deleted; corrections are new, balanced
  postings.
- Money arithmetic uses `App\Support\Money` (`brick/math`); no
  floating-point arithmetic.

| Account | Meaning |
|---|---|
| `rider_cash` | Cash a rider is physically holding |
| `platform_cash` | Cash handed in to the sorting center / Picksell |
| `order_funds` | Buyer money received for an order, not yet allocated |
| `seller_payable` | Owed to a seller |
| `rider_payable` | Owed to a rider |
| `withholding_tax` | Withheld from sellers (only if withholding is enabled) |
| `platform_revenue` | Commission, shipping and fees kept, minus platform-funded costs |

### Settlement (when a seller is owed)
An order settles only when **all** of these hold:
- its cash is handed in (`paid`)
- `return_window_days` (7) have passed since delivery
- no return case is open
- its payment isn't under legacy review
- the ledger shows its cash unallocated (otherwise: a discrepancy, flagged
  for review)

Settlement runs daily (`php artisan picksell:settle-orders`, scheduled for
02:00 Philippine time) and from Admin → Finance. The 7-day hold is an operational choice,
not a statement that 7 days satisfies every consumer remedy; late defect
refunds are handled below.

| Component | Rule |
|---|---|
| Seller gross | Item price after **store** vouchers and item discounts. **Platform** vouchers are funded by Picksell: the seller is credited the pre-voucher price. |
| Seller refund | Refunds whose recorded funder is the seller, capped at seller gross |
| Commission | **10%** (`commission_rate`, **provisional**) × (seller gross − seller refund). Never on shipping or service fees, never charged twice. |
| Withholding | 0 unless enabled (see section 6) |
| Seller payable | Seller gross − seller refund − commission − withholding |
| Platform | Cash kept − seller payable − withholding |

Platform-funded refunds and platform vouchers reduce Picksell's share, never
the seller's.

**Refunds after settlement** (e.g. a defect claim on day 30) post a separate
`late_refund_adjustment`. A seller-funded refund reverses the seller's share
and the commission (and withholding) on it, at the rates recorded at
settlement; otherwise Picksell bears it. The settlement itself is never
edited, and the seller's next payout nets the adjustment.

### Payouts (manual, admin-approved)
1. Admin creates pending payouts for a period. They include each
   seller's/rider's unpaid settled lines, netting later adjustments. A payee
   whose net is zero or negative gets no payout yet. Each line can be in
   only one payout at a time.
2. Admin approves. With the two-person rule on
   (`payout_requires_second_admin`, for payouts at or above
   `second_admin_threshold`), the admin who created a payout can't approve
   it.
3. The money is transferred **outside Picksell** by an authorised operator.
4. Admin records the transfer reference and the **disbursement date**.
   Neither can be skipped, and the date can't be in the future.

Safeguards:
- A payout can't be approved or completed for more than the payee is
  currently owed.
- It can't be completed twice.
- A failed or cancelled payout releases exactly its own lines.
- Payouts are weekly by default (`payout_period`, **provisional**). Periods
  are Philippine calendar days, Monday to Sunday.

### Two-person approval: recommendation (needs approval; currently off)
- **Risks it addresses:**
  - one admin creating and approving a payout to the wrong payee or for
    the wrong amount, by mistake or on purpose
  - a compromised admin account emptying what sellers are owed
- **What it costs:**
  - two admins must be available, which slows payouts
  - with only **one** admin account, any payout at or above the threshold
    can't be approved at all
- **Recommendation:**
  1. Create a second admin account first.
  2. Then set `PICKSELL_PAYOUT_SECOND_ADMIN=true` with
     `PICKSELL_PAYOUT_SECOND_ADMIN_THRESHOLD=0`, so every payout needs a
     second admin while weekly volume is small.
  3. After about three months of payouts, consider raising the threshold to
     roughly the 80th percentile of payout amounts. Small routine payouts
     then flow, and large ones still get a second look.

  The threshold stays configurable; no amount is set until you approve it.
- **Controls outside the software:**
  - Picksell doesn't store payees' bank or e-wallet details; the transfer
    happens outside it.
  - The operator sending money must check the destination against the
    seller's or rider's verified details.
  - Any change to those details needs confirmation through a second
    channel.
  - Today only "approver ≠ creator" is enforced. The admin who marks a
    payout completed can be either of them.

### Reconciliation (Admin → Finance)
- cash at the sorting center, and cash still with riders
- amounts owed to sellers and riders, and what is in open payouts
- collected orders not yet handed in
- approved refunds not yet handed over
- returns waiting for admin; cases with undetermined responsibility
- legacy orders needing review
- settled orders with unallocated funds
- a ledger balance check

`php artisan picksell:preflight` also checks the ledger balance.

## 5. Rider compensation

### Status: not configured (no pay accrues)
Riders are treated as **independent contractors**. This is an operational
assumption, not a legal determination. Classification depends on the actual
working arrangement (DOLE's four-fold test). Nothing in the software makes
an arrangement compliant.

### The model (implemented, inactive)
- **`base_per_stop`:** for the first parcel delivered at an address. A stop
  is one rider, one delivery address, one day.
- **`additional_parcel`:** for each extra parcel at that stop.
- **`zone_adjustments`:** an extra amount by delivery municipality or
  province.
- **`failed_attempt`:** optional, per failed attempt.
- **Eligibility:**
  - Only the rider who delivered and collected the cash earns the delivery
    pay.
  - Pay accrues when that cash is handed in.
  - Cancelled orders, returned-to-seller parcels and reassignments earn
    nothing for the delivery itself.
  - Historical (backfilled) legacy orders earn nothing.
- **Recorded:** each accrual stores its rule, stop, base, zone and total in
  the ledger.
- **Funding:** rider pay is charged to Picksell's revenue, never to sellers.
  Platform commission is never counted as rider earnings.
- **Statuses:**
  - `unconfigured`: nothing shown or accrued.
  - `proposed`: the rates are shown to riders and admins as not active, and
    nothing accrues.
  - `active`: pay accrues.

  The rider page separates earned, owed now, and paid out.

### Research
- **Legal requirement:** DOLE Labor Advisory No. 14, s. 2021. Contractor
  riders' contracts must give "fair and equitable compensation, which shall
  not be lower than the prevailing minimum wage", plus SSS, PhilHealth and
  Pag-IBIG registration and safety measures.
  ([Conventus Law](https://conventuslaw.com/report/philippines-labor-advisory-on-working-conditions-of-delivery-riders-in-food-delivery-and-courier-activities/),
  [Mondaq](https://webiis10.mondaq.com/employee-rights-labour-relations/1270430/labor-advisory-on-working-conditions-of-delivery-riders-in-food-delivery-and-courier-activities))
- **Minimum wage reference** (checked 2026-10-26): payroll guides report
  Wage Order NCR-28 at **₱755/day** non-agriculture (₱718 for small retail
  and service), effective 2026-09-26, up from ₱695.
  - The NWPC's own NCR page still notes that NCR-27 awaits a final
    resolution from the Pasig and Navotas regional trial courts.
  - Confirm the order in force with the NWPC before payroll use, and use
    each region's own rate outside NCR.

  ([GreatDay HR](https://greatdayhr.ph/blog/ncr-28-wage-order-compliance-guide/),
  [Mercans](https://mercans.com/resources/statutory-alerts/philippines-rtwpb-ncr-wage-order-ncr-27-raises-metro-manila-floor-to-755-day/),
  [NWPC NCR](https://nwpc.dole.gov.ph/regionandwages/national-capital-region/))
- **Fuel** (October 2026, during the 2026 energy crisis): Metro Manila
  gasoline was about ₱88–94/L before a ₱4.30/L rollback on October 20. Check
  the DOE's weekly price notices before setting rates.
  ([DOE](https://doe.gov.ph/liquid-fuels-and-lpg-price-adjustments-for-6-13-october-2026),
  [Manila Bulletin](https://mb.com.ph/2026/10/19/gasoline-drops-430-but-diesel-jumps-260-per-liter),
  [Rappler](https://www.rappler.com/business/fuel-prices-adjustments-october-20-2026/))
- **No per-delivery minimum exists in law.** No 2026 statute or DOLE order
  sets one; the DOLE advisory's "not lower than the prevailing minimum
  wage" is the floor that applies.
- **Industry practice** (dated, secondary sources):
  - Lalamove: ₱49 base fare plus a distance fee, minus a 20% commission.
  - GrabFood (2021): ₱49 fee minus 20%, plus ₱15 per km.
  - A 2022 Senate hearing heard of riders earning as little as ₱15 a trip.

  ([PH Kule](https://phkule.org/article/1237/lalamove-no-show-at-dict-dialogue-on-riders-complaints),
  [Inquirer 2021](https://newsinfo.inquirer.net/1430610/lockdown-heroes-face-long-ride-to-basic-pay-safety-nets),
  [Inquirer 2022](https://newsinfo.inquirer.net/1675091/unfair-wages-group-says-some-riders-get-as-low-as-p15-per-delivery-due-to-competition))

### Cost model (illustrative; assumptions to confirm in the pilot)
A rider's day must cover their costs and still net at least the regional
daily minimum wage.

| Item (per working day, motorcycle, Metro Manila) | Assumption | ₱/day |
|---|---|---|
| Net earnings floor | NCR minimum (see above) | 755 |
| Fuel | ~80 km at ~40 km/L = 2 L at ~₱85–94/L | 170–190 |
| Maintenance, tyres, depreciation | estimate | 60–90 |
| Mobile data and phone | estimate | 20–30 |
| Social contributions the rider pays as self-employed (SSS, PhilHealth, Pag-IBIG) | spread over ~26 working days; verify current rates | 60–90 |
| **Gross needed** | | **≈ 1,065–1,155** |

Divided by stops per day, that gross gives the base pay a stop must carry:

| Stops per day | ₱ per stop |
|---|---|
| 20 | 53–58 |
| 25 | 43–46 |
| 30 | 36–39 |

Market references (₱45–50 per trip before platform commission) sit inside
this band.

### Recommendation (needs approval; not activated)
The model is already built: per stop, per extra parcel, zone adjustments
and an optional failed-attempt fee. These **ranges are for discussion and
are not configured**:

| Setting | Suggested pilot range | Why |
|---|---|---|
| `base_per_stop` (NCR) | ₱45–55 | Covers costs plus the wage floor at 20–25 stops per day |
| `additional_parcel` | ₱10–15 | Little extra time at the same stop |
| `failed_attempt` | ₱15–20 | The rider made the trip; discourages skipping hard addresses without penalising genuine failures |
| `zone_adjustments` | only where the pilot shows longer routes | — |

1. Run 2–4 weeks in `proposed` status, which shows rates but accrues
   nothing. Measure per rider and zone: stops per day, parcels per stop,
   kilometres and hours.
2. Choose rates so that a typical full day nets at or above the regional
   minimum after the costs above.
3. Review when the pump price moves by more than about ₱10/L or a new wage
   order takes effect.
4. Have counsel confirm the contractor classification and contract terms
   (DOLE LA 14-2021), including SSS, PhilHealth and Pag-IBIG registration.

**To activate:** set the approved amounts and
`PICKSELL_RIDER_PAY_STATUS=active`. Pay then accrues from the next cash
hand-in, never retroactively.

## 6. Tax withholding (RR 16-2023): available, not enabled

- **What the rule says** (per KPMG's and Grant Thornton's summaries of RR
  16-2023 and RMC 8-2024):
  - e-marketplace operators withhold 1% on one-half of gross remittances
    to sellers
  - gross remittances exclude sales returns, discounts, separately billed
    delivery fees, VAT, and the platform's own fees
  - **cash collected from buyers by persons or entities, such as COD, is
    listed as covered**
  - exempt: sellers whose remittances haven't exceeded ₱500,000 (across
    all platforms), with a BIR-received sworn declaration filed by the 20th
    of January each year; and sellers exempt or taxed at lower rates by law
    or treaty, with proof
  - sellers must give the platform their BIR Certificate of Registration
    (Form 2303)

  ([KPMG](https://kpmg.com/ph/en/insights/2024/01/special-intax-january-2024-issue-1-volume-1.html),
  [Grant Thornton](https://www.grantthornton.com.ph/insights/articles-and-updates1/lets-talk-tax/withholding-tax-rules-on-digital-commerce/),
  [Baker McKenzie](https://insightplus.bakermckenzie.com/bm/tax/philippines-bureau-of-internal-revenue-issues-regulations-on-withholding-tax-on-remittances-by-online-platforms-to-online-sellersmerchants))
- **Implemented:**
  - the base calculation (seller item value net of seller-funded refunds and
    discounts, before commission)
  - a separate `withholding_tax` account, reversal on late refunds
  - seller tax profiles: TIN, COR number, sworn-declaration year and
    receipt date, exemption type and reference, verified by/at
- **Not implemented:**
  - automatic exemption checks (threshold tracking per seller, all
    platforms)
  - BIR Form 2307 certificates
  - filing and remittance reports
- **Before enabling:**
  - a qualified Philippine tax professional confirms the treatment of a
    COD-only marketplace and the base for platform-funded vouchers
  - exemption evidence is recorded and validated
  - certificates and reporting are built and reconciled

  Until then `PICKSELL_WITHHOLDING_ENABLED` stays `false`. The admin page
  says "not legally validated or enabled".

## 7. Orders delivered before COD tracking (legacy)

- Orders delivered before this workflow have no collection record. They
  show `unpaid`, are listed under Admin → Finance → "Orders Delivered Before
  COD Tracking", and are **never** marked paid automatically.
- **Record historical payment:** admin only, one order at a time, never in
  bulk. It requires:
  - the exact order total
  - an evidence reference (e.g. remittance sheet or deposit slip number)
  - a reason the evidence is trustworthy
  - the collection date, only if the evidence shows it

  It posts a `cod_backfill` ledger entry marked `historical`, sets
  `payment_backfilled_at`, and leaves `paid_at` empty rather than invent a
  hand-in time. It never earns rider pay. Afterwards the order settles and
  refunds normally.
- **Mark unverifiable:** used when no trustworthy evidence exists. The
  order is excluded from settlement and its refunds are blocked until
  evidence turns up; the backfill can still be recorded later.

**Evidence needed to record a historical collection.** At least one
document showing the cash reached Picksell, plus enough to tie it to this
order:

| Evidence | Shows | Required? |
|---|---|---|
| Sorting-center remittance sheet or hand-in log, signed or initialled by the receiving staff, listing the order number and amount | Cash reached Picksell | One of these three |
| Bank deposit slip or bank statement line for a deposit that includes the amount, with a deposit sheet listing the order | Cash reached Picksell | One of these three |
| Rider's cash turnover receipt countersigned by staff | Cash reached Picksell | One of these three |
| The rider's statement of the delivery date and the amount collected | Collection, and the date if stated | Supporting |
| Buyer confirmation (receipt, message or call note) that they paid ₱X in cash | Collection | Supporting |
| Proof of delivery (signature, photo, recipient name) | Delivery | Supporting |

**Rules:**
- The amount must equal the order total exactly.
- Record the collection date only if the evidence states it.
- An admin records the evidence reference and the reason it's trusted. That
  writes a `cod_backfill` ledger entry, an audit log entry, and
  `payment_backfilled_at`.
- With no such evidence, use **Mark unverifiable** and note what was
  checked.

**PS-51351586 and return #2 (development data).** Delivered 2026-10-20,
total ₱1,537.88, voucher WELCOME50, `unpaid`. Return #2 is `requested`,
asking ₱746.44, with a legacy `refund_to = gcash`.

*Findings (read-only check of dev MySQL, 2026-10-26):*
- Every party on the order is a seeded demo account: `buyer@picksell.ph`,
  `seller@picksell.ph`, `rider1@picksell.test` and
  `logistics@picksell.test`.
- The whole lifecycle took six seconds. It was placed at 22:27:56 UTC,
  every step from packing to delivery happened between 22:27:59 and
  22:28:01, and the return was requested at 22:28:02. That is a scripted
  test run, not a real delivery.
- There are no delivery attempts, recipient name, proof of delivery, audit
  log or ledger entries.
- So there was no real cash: no evidence of a collection can exist.
- The case is **left unresolved**, as instructed. The auditable way to
  close it is **Mark unverifiable**, noting "development test data; no
  cash was collected", then rejecting return #2 with the same note. Both
  need your decision.
- Development data must never be migrated to production.

Steps for a real legacy case like this:
1. Look for evidence the rider's ₱1,537.88 was received: remittance sheet,
   hand-in log, or deposit.
2. If found: in Admin → Finance, record the historical payment with that
   reference. If not: mark it unverifiable with what was checked.
3. Review return #2 in Admin → Returns. Approving it sets the refund method
   to cash. GCash is not available, so the buyer must be told the refund
   will be cash.
4. If verified, the case proceeds normally (pickup, inspection, release,
   hand-over). If unverifiable, the refund stays blocked and the case is
   escalated to a manager. **No refund is released and no settlement made
   until the payment record is consistent.**

## 8. Decisions needing approval
- Commission rate (10%, items only).
- Return windows: 7 days change-of-mind / 60 days defect claims (confirm
  with counsel).
- Responsibility presumptions and funding rules (section 3).
- Rider pay rates and status, and rider classification.
- Payout cycle (weekly), and turning on the two-person rule and its
  threshold.
- Platform vouchers funded by Picksell.
- Tax withholding activation (section 6).
- How to close PS-51351586 / return #2 (development data, section 7).

**Decided:** times are shown, grouped into days and scheduled in
Philippine time (Asia/Manila). Storage stays UTC, so existing records
aren't rewritten. See `deployment.md`.
