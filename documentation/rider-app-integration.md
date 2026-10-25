# Rider app integration: proposed backend contract

**Status: design for approval. Nothing below the "Proposed API" heading is
implemented.**

The Rider mobile app is built in a separate environment. This repository
does not contain it, and nothing in this work inspected or changed it. It
is an external client of the Picksell backend.

Verified against the backend on 2026-10-26 (branch
`feature/buyer-mobile-app`). Every rule below is enforced today by the
services named, through the rider web pages under `/courier`. A rider API
would call the same services, so the rules can't diverge.

## 1. What exists today (web, session login)

| Action | Route (web) | Service | Enforced rules |
|---|---|---|---|
| Set out for delivery, or retry after a failed attempt | `PATCH /courier/orders/{order}/status` `status=shipped` | `Deliveries::setOut` | Must be the assigned rider (403). Step must be *assigned to rider* or *delivery failed* (422). Attempts must be below `max_attempts`, default 3 (422). |
| Deliver: COD cash + proof of delivery | `PATCH /courier/orders/{order}/status` `status=completed, cash_collected, recipient_name, proof_photo?, note?` | `Deliveries::deliver` → `CodPayments::deliverAndCollect` | Assigned rider (403). Step must be *out for delivery* (422). COD only, and payment not already recorded (422). `cash_collected` must equal the order total **exactly** (422). `recipient_name` required. Photo optional: jpg/png/webp, ≤5 MB. The cash, proof and status are saved together or not at all. |
| Failed attempt | `POST /courier/orders/{order}/failed` `reason, note?, proof_photo?` | `Deliveries::fail` | `reason` must be one of `picksell.delivery.failed_reasons` (422). Assigned rider (403). Step must be *out for delivery* (422). |
| Return item picked up (no cash) | `POST /courier/returns/{return}/picked-up` | `ReturnWorkflow::recordPickup` | Must be the assigned pickup rider (403). Once only (422). |
| Hand a refund to the buyer | `POST /courier/refunds/{return}/handover` `amount, item_collected?` | `ReturnWorkflow::handOverRefund` | Must be the rider holding the cash (403). The refund must have been released to them (422). `amount` must equal the approved refund exactly (422). For an expedited refund, the item must be collected at the same time (422). Once only. |

**Done by sorting-center staff, not by riders:**

| Action | Route | Effect |
|---|---|---|
| Confirm a rider's cash hand-in | `POST /logistics/cash/riders/{courier}/remit` `order_ids[]` | `collected` → `paid`. The rider's cash balance goes down. Each order is confirmed once. |
| Release refund cash to a rider | `POST /logistics/refunds/{return}/release` `courier_id` | The cash moves to the rider's cash balance. Refused while the refund is blocked (e.g. waiting for inspection, or the payment is unverified). |
| Take refund cash back | `POST /logistics/refunds/{return}/cancel` | Reverses a release that wasn't handed over. |
| Assign a return pickup | `POST /logistics/returns/{return}/pickup` `courier_id` | — |
| Send a parcel back to the seller | `POST /logistics/parcels/{order}/return-to-sender` `reason` | Only after a failed delivery. |

**There are no rider JSON endpoints yet:**
- `POST /api/login` answers 403 "This app is for buyers only." to riders.
- Every `/api/buyer/*` route requires the buyer role.

## 2. Status transitions a rider sees

```
assigned_to_rider ──set out──▶ out_for_delivery ──deliver (exact cash + recipient)──▶ delivered
                                  │                                                   payment: unpaid → collected
                                  └─fail (reason)─▶ delivery_failed ──set out again──▶ out_for_delivery
                                                        │  (until max_attempts)
                                                        └─sorting center─▶ returned ─▶ seller receives it

collected ──sorting center confirms hand-in──▶ paid      (the rider can't do this step)

Return pickup:  case resolved, pickup assigned to me ──picked up──▶ item collected
Refund cash:    released to me ──hand over exact amount──▶ refunded
                └─(sorting center takes it back)─▶ released again or cancelled
```

## 3. Proposed API (not implemented)

### Authentication and permissions
- **Login:** `POST /api/rider/login {email, password}` → `{token, user}`.
  - Only `courier` accounts with `status = approved`.
  - Same lockout and rate limit as buyer login: 10 per minute per IP.
  - Wrong role or status: the same generic error as a wrong password, so it
    doesn't reveal which accounts exist.
- **Token:** a Sanctum bearer token with ability `rider`.
  - Expires with `SANCTUM_EXPIRATION` (30 days).
  - Revoked on logout and password change.
  - Becomes useless as soon as the account is suspended: every request
    re-checks the role and approval, like `CourierMiddleware` does.
- **Middleware for every rider route:** `auth:sanctum` +
  `ability:rider` + role `courier` + approved.
- **Per record:** the assigned-rider checks in the services (403) apply
  unchanged.
- **Privacy:** a buyer's phone and address appear only while the parcel is
  assigned to this rider and not yet delivered or returned.
- **Password reset:** the buyer-app flow, extended to the courier role.

### Endpoints

| Method & path | Purpose | Calls |
|---|---|---|
| `GET /api/rider/tasks` | My parcels: status, delivery contact, `cod_due` (centavos + formatted), attempts used / max | — |
| `POST /api/rider/tasks/{order}/out-for-delivery` | Set out, or retry | `Deliveries::setOut` |
| `POST /api/rider/tasks/{order}/deliver` (multipart) `{cash_collected, recipient_name, proof_photo?, note?}` | Delivered + COD collected | `Deliveries::deliver` |
| `GET /api/rider/failed-reasons` | Allowed reasons | config |
| `POST /api/rider/tasks/{order}/failed` (multipart) `{reason, note?, proof_photo?}` | Failed attempt | `Deliveries::fail` |
| `GET /api/rider/pickups` | Return items to collect | — |
| `POST /api/rider/pickups/{return}/collected` | Item collected; no cash | `ReturnWorkflow::recordPickup` |
| `GET /api/rider/refunds` | Refund cash released to me, not yet handed over | — |
| `POST /api/rider/refunds/{return}/hand-over` `{amount, item_collected?}` | Refund handed to the buyer | `ReturnWorkflow::handOverRefund` |
| `GET /api/rider/cash` | Cash I hold (`rider_cash`, which includes released refund cash), and the parcels to hand in | `Ledger::balance` |
| `GET /api/rider/earnings` | Pay policy `status` and rates; accrued, owed and paid; each accrual's calculation | ledger `details` |

**Cash hand-in stays a sorting-center action.** The app only shows what the
rider holds; staff confirm the cash they physically receive.

### Compatibility requirements for the Rider app
1. **Money:**
   - The server sends integer centavos plus a formatted string.
   - The app sends cash as a decimal peso string (`"1537.88"`).
   - The amount must match exactly: there's no rounding, and no change or
     partial payment is recorded.
2. **Times:** ISO-8601 in UTC (`…Z`). Show them in the device's local time
   (Philippine time for PH riders).
3. **Photos:** multipart field `proof_photo`, jpg/png/webp, ≤5 MB.
   - Compress on the device.
   - Photos are private: only admins and sorting-center staff can view
     them.
4. **Only a 2xx response means success.** Error bodies are
   `{message, errors?}`:

   | Code | Meaning |
   |---|---|
   | 401 | Token missing, expired or revoked |
   | 403 | Not assigned to me, or account not approved |
   | 422 | Wrong step, wrong amount, already recorded, or validation |

5. **Retries:** each action is recorded once. A repeat returns 422 (e.g.
   "Payment for this order was already recorded."), never a double entry.
   After a timeout, the app must reload the task (`GET /api/rider/tasks`)
   to learn whether the first attempt succeeded, not retry blindly.
6. **Offline:** queue actions locally, send them in order, and stop on the
   first 4xx. COD and refunds are cash events, so there are no optimistic
   balance updates: show the server's figures.
7. **Versioning:** routes live under `/api/rider`. Breaking changes need a
   new prefix (`/api/rider/v2`) while old app versions are still in use.

### Decisions needed before implementation
- Approve this contract: endpoints, fields, errors.
- Whether riders may see a buyer's phone number at all, or only use a
  masked call or relay.
- Whether a photo becomes **required** for delivery (today it's optional;
  the recipient name is required) or for failed attempts.
- Who builds the rider endpoints in this backend, and when. They need
  feature tests per endpoint, matching the web-page tests in
  `DeliveryOperationsTest`, `CodPaymentTest` and `ReturnWorkflowTest`.

## 4. Not verifiable until the Rider app integrates
- end-to-end delivery, collection, pickup and refund hand-over from the app
  (today verified through the `/courier` pages and feature tests)
- camera upload sizes and formats from real phones
- offline queueing and recovery after a timeout
- the rider token lifecycle (no rider API yet)

Push events the Rider app will want are listed in `notifications.md`.
