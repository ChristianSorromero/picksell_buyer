# Order and parcel reconciliation report

Phase 3 stabilization, 2026-11-01. Database findings come from read-only `SELECT`s on the local
MySQL `picksell` database. Every write described here was made only in the disposable copy
`picksell_stabilization`.

## 1. Two status vocabularies and how they connect

**Order** (`orders.status`, `App\Services\Orders\OrderLifecycleService::TRANSITIONS`, identical in
Picksell and picksell-buyer):

```
placed → confirmed → preparing → ready_for_pickup → picked_up → at_sorting_center → sorted
  → assigned_to_rider → out_for_delivery → delivered → completed
assigned_to_rider → at_sorting_center        (rider dropped it back at the hub)
out_for_delivery  → delivery_failed → at_sorting_center | returned
placed/confirmed/preparing/ready_for_pickup → cancelled
legacy: pending, processing, shipped (moved onto the lifecycle by an admin)
```

**Parcel** (`pr_parcels.current_status`, `App\Pickrush\Enums\ParcelStatus::TRANSITIONS`): 16 states,
including the line-haul states `in_transit_to_province`, `at_province_hub` and
`in_transit_to_station`, plus `on_hold`, `returning_to_sender`, `lost` and `cancelled`. Every
change is a `pr_parcel_events` row, and `ParcelLedger::record()` is the only writer.

**The link** is `App\Pickrush\Bridge\SyncOrderWithParcel`, which listens for
`ParcelStatusChanged`. It runs inside the scan request, after the commit, with no queue:

| Parcel scan | Order status |
|---|---|
| picked_up | picked_up |
| at_origin_hub | at_sorting_center |
| arrived_at_station, at the parcel's **destination** station only | sorted |
| assigned_to_rider | assigned_to_rider |
| out_for_delivery | out_for_delivery |
| delivered | delivered |
| delivery_failed | delivery_failed |
| returned_to_sender | returned |
| cancelled | cancelled |
| in_transit_*, at_province_hub, on_hold, … | no status change; only `tracking_status` (the buyer's "where is it" line) |

- **Skipping:** the sync may skip `picked_up`, `at_sorting_center` and `sorted` (walk-ins, same-city parcels). It never skips anything else.
- **Refused moves:** a move the lifecycle forbids raises an admin alert ("Order out of step with Pickrush", `pickrush.sync_failed`). The order only gets the tracking note, and the scan itself is always kept.
- **Seller confirmation:** `completed` comes only from the seller's "confirm delivery" (`SellerController::confirmDelivery`). That step also posts the financial transactions.

## 2. Buyer-facing mapping

Status values, labels and tabs agree across `app/Support/OrderStatus.php` (both APIs) and
`lib/core/status/order_status.dart`:

| Tab | Statuses |
|---|---|
| To Ship | placed, confirmed, preparing, ready_for_pickup |
| In Transit | picked_up, at_sorting_center, sorted, assigned_to_rider |
| Out for Delivery | out_for_delivery, delivery_failed |
| To Rate | delivered, completed (not yet rated) |
| Completed | delivered, completed (rated), returned |
| Cancelled | cancelled |

"To Be Delivered" doesn't appear anywhere in the three codebases. The rider action the
original report described is **Start Route**, which moves the parcel and the order to
`out_for_delivery` and the buyer's order to the Out for Delivery tab. Loading parcels onto the
vehicle changes no status, by design.

## 3. Root cause of the stuck orders (fixed)

`Order::recordStatusChange()` credited `auth()->user()`. On the Pickrush portal that is a
**`pr_staff`** row (the `pickrush` guard), but `order_status_histories.changed_by` is a foreign key
to `users`:

- **Staff ID with no matching user:** the insert failed, the sync rolled back, and the order froze.
- **Staff ID that matched a user:** the history credited an unrelated website account.

**Fix:** only an `App\Models\User` is credited. It's in both copies of `Order.php`, and the
`production` branch carries the same fix (commit `b36b37d`). Covered by
`tests/Feature/Pickrush/StaffScanOrderSyncTest.php`.

## 4. Records found inconsistent (real database, read-only)

| Order | Order status | Parcel | Parcel status | Scans the order missed |
|---|---|---|---|---|
| 5 `ORD-C2EAQKIS` | at_sorting_center (`tracking_status` "Delivered") | 4 `PR2610202452503J` | delivered 2026-10-24 12:10:46 | arrived_at_station 10:51:25, assigned_to_rider 11:02:24, out_for_delivery 12:08:21, delivered 12:10:46 |
| 24 `ORD-U1ELMPWU` | at_sorting_center (`tracking_status` "Delivered") | 1 `PR2610209681854S` | delivered 2026-10-24 12:10:46 | arrived_at_station 10:51:27, assigned_to_rider 11:02:24, out_for_delivery 12:08:21, delivered 12:10:46 |

Supporting facts:
- Both deliveries were completed by rider 3. COD of ₱216.00 and ₱89.10 was collected and remitted (remittance 1).
- Neither order has financial transactions. Those post only at `completed`, which the seller can't reach while the order is behind.
- Buyer 3 received only the "picked up" notification for each order.

| History row | Order | Step | `changed_by` | Who actually did it |
|---|---|---|---|---|
| 127 | 24 | at_sorting_center | 6 = **buyer** account (role buyer) | Pickrush staff 6, "Test Cebu City Station Manager" (`pr_parcel_events`, actor staff 6) |
| 128 | 5 | at_sorting_center | 6 = **buyer** account | Pickrush staff 6 |

- **Order 25** doesn't exist in this database. The log copied from the other PC shows the same
  failure for an order 25 there (2026-10-30, staff 15), so it must be checked on that machine.
- **Alerts:** eight `pickrush.sync_failed` admin alerts (2026-10-24) belong to orders 5 and 24, and are still unread in the admin inbox.
- **Whose data:** these records are local development data copied from the other PC. No tunnel or
  server was running on this PC, and `pick-sell.shop` resolves to Cloudflare. Which database the
  live domain uses can't be determined from here.

## 5. Repair tool (built and tested; not run on real data)

`php artisan pickrush:reconcile-order {order…} [--apply]` (Picksell,
`app/Pickrush/Console/Commands/ReconcileOrder.php`):

- **What it replays:** the parcel scans recorded after the order's last Pickrush step, through the existing `SyncOrderWithParcel`. So it follows the normal lifecycle rules and adds no new status logic.
- **Original times:** each replay runs at the scan's original time, so `sorted_at` … `delivered_at`, the history rows and the buyer's messages carry the real scan times.
- **Wrong credits:** it clears `changed_by` on that order's Pickrush history rows. A scan is never made by a website account.
- **Dry run by default:** everything happens in a transaction that is rolled back.
- **Stops on refusal:** if any scan is still refused, the order is rolled back and the command reports the failure.
- **Audit:** with `--apply`, it writes one `pr_audit_logs` row (`Parcel.order_reconciled`) per order that changed.
- **Idempotent:** a second run changes nothing and logs nothing.

Tests: `tests/Feature/Pickrush/ReconcileOrderTest.php` (dry run, apply, idempotent rerun, refusal).

### Rehearsal on the disposable copy

The dry run and then `--apply` on `picksell_stabilization` gave:

| Order | Steps added (at original times) | Result | History uncredited |
|---|---|---|---|
| 5 | sorted 10:51:25, assigned_to_rider 11:02:24, out_for_delivery 12:08:21, delivered 12:10:46 | delivered, `delivered_at` 2026-10-24 12:10:46 | 128 |
| 24 | sorted 10:51:27, assigned_to_rider 11:02:24, out_for_delivery 12:08:21, delivered 12:10:46 | delivered, `delivered_at` 2026-10-24 12:10:46 | 127 |

- **Buyer notifications:** buyer 3 got the three missed notifications per order (sorted, out for delivery, delivered), dated at the scan times.
- **Rerun:** "0 scans to replay", no audit row.
- **Alerts:** no new sync alerts.

## 6. Repair plans awaiting approval

**Orders 5 and 24, and history rows 127 and 128 (local `picksell` database)**

| | |
|---|---|
| Current state | See section 4. |
| Correction | `php artisan pickrush:reconcile-order 5 24` (review the dry run), then the same command with `--apply`. |
| Justification | The parcels were delivered, with COD collected and remitted. The orders only missed the scans because of the fixed defect. |
| Side effects | Each order goes to `delivered` with the original timestamps. The buyer gets three dated notifications per order. Rows 127 and 128 lose the wrong buyer credit. The seller can now "confirm delivery" to reach `completed`, which posts the commission and payout transactions. |
| Before running | Take a `mysqldump` of `picksell`. The command needs a working Picksell `.env` (see REMAINING_WORK item E1), or the same process-environment override used in this run. |
| Rollback | Restore the dump. Alternatively, reverse it by hand: the audit row lists the added history ids and the uncredited rows (`changed_by` was 6). |
| Afterwards | Mark the eight old "Order out of step with Pickrush" admin alerts as read. |

**Order 25 (other PC):** run the same dry run there first. Apply only if it shows the same
pattern (all scans followable, no refusal).

## 7. Remaining lifecycle gaps (not changed)

| Gap | Evidence | Effect | Needs |
|---|---|---|---|
| A parcel sent back to the seller **before** the destination station can't move its order to `returned` | `ExceptionDesk` can send `on_hold` and hub parcels to `returning_to_sender`. The lifecycle only allows `returned` from `delivery_failed`. | That order stays `at_sorting_center`/`sorted` and raises an admin alert | A business-rule decision: allow `at_sorting_center`/`sorted → returned`? |
| `lost` parcels | The sync only alerts admins. The order has no matching status. | The order stays where it was | A business decision (refund or replacement flow) |
| `in_transit` order status | In the DB enum and in some website badges and filters (`SellerController:42,59`, `order-status-badge`), but not in the lifecycle or the app | If ever written, the app shows "Order Placed" in To Ship. **0 rows** today. | Decide: drop it from the enum, or map it |
| Orders 22 and 23 | `ready_for_pickup` since 2026-10-09 with legacy waybills (`WB-261009-…`) and **no Pickrush parcel** | Nothing will ever collect them | The owner books them with Pickrush or cancels them |
| Orders 9–16 | Demo orders (`WB-DEMO-…`) at various delivery steps with no parcel | No tracking | Leave as demo data, or remove with approval |
| Orders 1 and 2 | Legacy `processing` / `shipped` | The admin can move them onto the lifecycle | Admin decision |
| Notification failure after a successful move | In `SyncOrderWithParcel::sync()`, `notify()` runs after the commit but inside the same `try` | A failed notification would raise a misleading "could not follow" alert for an order that **did** move | Low priority: move `notify()` out of the `try`, or word the alert differently |

## 8. Idempotency and retries (verified)

- **Live run on the copy:** the rider's "start route" and "deliver" were each sent twice with the same request key. Both returned 200, and the parcel ended up with exactly one `out_for_delivery` and one `delivered` event.
- **Ledger:** `ParcelLedger` returns the existing event for a repeated idempotency key.
- **Re-applying a status:** the sync is a no-op when the target equals the current order status.
- **Real database:** no duplicate idempotency keys, and every parcel's status matches its last event.
