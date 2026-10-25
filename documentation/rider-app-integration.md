# Rider app integration: what the backend needs to expose

The Rider mobile app is built in a separate environment. This repository
does not contain it and has not changed it.

Today, riders (role `courier`) use the web pages under `/courier`:
- **Delivery Tasks:** mark a parcel out for delivery; mark it delivered
  while entering the cash collected.
- **Refunds to Hand Over:** confirm a refund was handed to the buyer, and
  that the item was collected when it has to come back.

These pages call the same services the Rider app will need:
- `App\Services\CodPayments::deliverAndCollect`
- `App\Services\ReturnWorkflow::handOverRefund`

No JSON endpoints for riders exist yet. Every route under `/api/buyer/*` is
restricted to buyers, and `POST /api/login` rejects non-buyer accounts.
Below is the proposed contract. It is not implemented.

## Authentication
`POST /api/rider/login {email, password}` → `{token, user}`
- Approved `courier` accounts only.
- Issues a Sanctum token with the `rider` ability.

Every rider route would use the `auth:sanctum` middleware plus a check
that the user is an approved courier (equivalent to `EnsureActiveBuyer`).

## Endpoints

| Method & path | Purpose | Rules |
|---|---|---|
| `GET /api/rider/tasks` | Parcels assigned to me, with status, `delivery` (recipient, phone, address, landmark) and `cod_due` | `courier_id = me` |
| `POST /api/rider/tasks/{order}/out-for-delivery` | Assigned → out for delivery | `OrderStatus::ensure($order, 'out_for_delivery')`; 403 if not mine |
| `POST /api/rider/tasks/{order}/deliver` `{cash_collected}` | Delivered and cash collected, recorded together | Amount must equal the order total; only once; payment becomes `collected` |
| `GET /api/rider/cash` | Cash I'm holding (`rider_cash` balance) and parcels not yet handed in | — |
| `GET /api/rider/refunds` | Refunds released to me | `refund_courier_id = me`, not yet handed over |
| `POST /api/rider/refunds/{return}/hand-over` `{amount, item_collected}` | Refund handed to the buyer | Amount must equal the approved refund; `item_collected` required when the item must come back; only once |
| `GET /api/rider/earnings` | Rider pay accrued and payouts | `rider_payable` balance and payouts |

**Error responses**
- `422 {message}`: wrong amount, wrong step, or already recorded.
- `403`: the parcel isn't assigned to me.

**Status transitions** are as described in `finance-returns-payouts.md`.
The backend is authoritative. The app must not assume a step succeeded
without a 2xx response.

## What can't be verified until the app integrates
- End-to-end collection and refund hand-over from the app (today it is
  verified only through the `/courier` web pages and feature tests).
- Offline or retry behaviour. The backend is idempotent: a repeated submit
  returns 422 "already recorded" and never double-counts.
- Proof of delivery (photo or code). Not implemented; it would attach to
  the deliver and hand-over calls.
