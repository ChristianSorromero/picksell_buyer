# Rider app integration: what the backend needs to expose

The Rider mobile app is built in a separate environment. This repository
does not contain it, and nothing here has inspected or changed it. It is an
external client of the Picksell backend.

## What exists in this repository today
Riders (role `courier`) use the web pages under `/courier`:

| Action | Route | Service |
|---|---|---|
| Set out for delivery (and retry after a failed attempt) | `PATCH /courier/orders/{order}/status` `status=shipped` | `Deliveries::setOut` |
| Deliver: COD cash + proof of delivery | `PATCH /courier/orders/{order}/status` `status=completed, cash_collected, recipient_name, proof_photo?` | `Deliveries::deliver` → `CodPayments::deliverAndCollect` |
| Record a failed attempt | `POST /courier/orders/{order}/failed` `reason, note?, proof_photo?` | `Deliveries::fail` |
| Record a return pickup (no cash) | `POST /courier/returns/{return}/picked-up` | `ReturnWorkflow::recordPickup` |
| Hand over a refund | `POST /courier/refunds/{return}/handover` `amount, item_collected?` | `ReturnWorkflow::handOverRefund` |

No JSON endpoints for riders exist yet. Every `/api/buyer/*` route is
restricted to buyers, and `POST /api/login` rejects non-buyers. The contract
below is a **proposal, not implemented**. The services above are what it
would call, so the rules stay identical.

## Proposed contract

**Authentication:** `POST /api/rider/login {email, password}` → `{token, user}`
- Approved `courier` accounts only.
- Sanctum token with the `rider` ability.
- Every rider route checks the token, the role and `status = approved`.

| Method & path | Purpose | Rules / errors |
|---|---|---|
| `GET /api/rider/tasks` | Parcels assigned to me: status, `delivery` (recipient, phone, address, landmark), `cod_due` (centavos and formatted), attempts used / max | `courier_id = me` |
| `POST /api/rider/tasks/{order}/out-for-delivery` | Assigned or failed → out for delivery | 403 not mine; 422 wrong step or attempts exhausted |
| `POST /api/rider/tasks/{order}/deliver` (multipart) `{cash_collected, recipient_name, proof_photo?}` | Delivered + COD collected, recorded together | 422 unless `cash_collected` equals the order total exactly; once only |
| `POST /api/rider/tasks/{order}/failed` (multipart) `{reason, note?, proof_photo?}` | Failed attempt | `reason` from `GET /api/rider/failed-reasons`; 422 wrong step |
| `GET /api/rider/pickups` | Return items to collect | `pickup_courier_id = me` |
| `POST /api/rider/pickups/{return}/collected` | Item collected; no cash | 403 not mine; 422 already collected |
| `GET /api/rider/refunds` | Refund cash released to me | `refund_courier_id = me`, not yet handed over |
| `POST /api/rider/refunds/{return}/hand-over` `{amount, item_collected?}` | Refund handed to the buyer | Amount must equal the approved refund; `item_collected` required on expedited refunds; once only |
| `GET /api/rider/cash` | Cash I hold (`rider_cash`) and parcels to hand in | — |
| `GET /api/rider/earnings` | Pay policy `status` (unconfigured / proposed / active) and rates; accrued, owed and paid amounts; per-delivery calculation from ledger `details` | Never includes platform commission |

**Errors:**
- `422 {message, errors?}`: wrong amount, wrong step, already recorded, or
  validation.
- `403`: not assigned to me.
- `401`: token missing, expired or revoked.

**State rules are enforced by the backend.** The app must treat only a 2xx
response as success. Repeated submissions are safe: they return 422
"already recorded" and are never double-counted.

**Proof-of-delivery photos** are private files. The app uploads them; only
admins and sorting-center staff can view them.

## Events the Rider app will want (for future push)
- a parcel assigned to me
- a pickup assigned to me
- refund cash released to me
- a parcel reassigned away from me
- my payout completed

See `notifications.md`.

## Not verifiable until the Rider app integrates
- end-to-end delivery, collection, pickup and refund hand-over from the app
  (today verified only through the `/courier` pages and feature tests)
- photo upload from a phone camera and image size limits
- offline queueing and retries (the backend is idempotent)
- rider login and token lifecycle for the rider role (no rider API yet)
