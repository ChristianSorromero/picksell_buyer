# Security and data-integrity report

Phase 3 stabilization, 2026-11-01. The access probes ran against local servers on the
disposable copy. The integrity checks are read-only queries on the local `picksell` database.
Nothing was probed on a deployed system.

## 1. Guards and boundaries

| Identity | Guard and storage | Verified |
|---|---|---|
| Website users (buyer, seller, admin) | `web` session guard, `users` | LIVE: a seller can't open `/admin/dashboard` (redirected) or another seller's order (403) |
| Buyer app | Sanctum tokens in `personal_access_tokens` (30-day expiry), `active.buyer` / `buyer.api` middleware | LIVE: no or bad token → 401; another buyer's order, cancel or rate → 404; another buyer's cart line → 404 |
| Pickrush staff | `pickrush` session guard, `pr_staff`, own cookie `pickrush_session` on the Pickrush host | LIVE: a marketplace session on the portal → login page; a portal session on `/admin/dashboard` → login page |
| Riders | own bearer tokens, stored as SHA-256 in `pr_rider_tokens`; `pickrush.rider[:active]` | LIVE: a buyer token on the rider API → 401; a rider token on the buyer API → 401; another rider's batch → 404 |

**Guard leak (fixed):** a Pickrush staff ID was written as a website user ID in
`order_status_histories.changed_by`. Fixed in both `Order.php` copies; see the reconciliation
report.

**Other actor writers checked.** These fall back to the default guard:
- `AuditLogger::record`
- `FinancialLedgerService` (`created_by`)
- `User::booted` (`user_status_histories.changed_by`)
- `ReturnDisputeResolution`
- `PlatformSettingsService`

None of them is reachable from Pickrush code: Pickrush touches the website only through `Order`,
`OrderLifecycleService`, `AdminNotificationService` (no actor column) and the PSGC geo models.
This is a **latent risk** only. Any future call from a Pickrush request into those services
would repeat the defect. Recommended low-priority hardening: the same `instanceof User` check
in those five places.

## 2. Ownership and role checks (server side)

| Check | Where | Result |
|---|---|---|
| Buyer reads or changes only their own orders | buyer `OrderController` queries scoped to `buyer_id` | LIVE 404 for others |
| Buyer cart lines | `CartController` scoped to the buyer's cart | LIVE 404 |
| Chat | `ChatController::messages` returns only the buyer's own thread | LIVE: arbitrary user id → empty thread, no leak |
| Seller orders | `SellerController` `abort_if(seller_id …, 403)` | LIVE 403 |
| Rider batches | `RiderBatches::own()` | LIVE 404 |
| Station staff | `ParcelHubScope` / `HubOwned` global scopes, `pickrush.station` middleware | TEST (`PortalAccessTest`, `StationOperationsTest`) |
| Admin operations | `Permission` gates per route; audit plus rollback on audit failure | TEST (`AdminOperationAuthorizationTest`) |
| One superadmin | `users` has exactly one admin account | DB |

## 3. Findings

| # | Finding | Severity | Evidence | Recommendation |
|---|---|---|---|---|
| S1 | Rider tokens never expire (revoked only on logout or deactivation) | Low | `RiderToken::issue` has no expiry; `RiderToken` middleware only refreshes `last_used_at` | Add an expiry (e.g. 30 days idle) when convenient |
| S2 | ID uploads and return/complaint evidence are on the **public** disk | Medium | Already documented in `documentation/shared-database.md` (website-side gap); files are under `storage/app/public/uploads/ids` | Move to private storage with signed routes (a website change; needs approval) |
| S3 | Picksell's local `.env` is a **production** file: `APP_ENV=production`, `SESSION_DOMAIN=.pick-sell.shop`, real SMTP; `APP_DEBUG=false` | Medium (operational) | env inspection (values not printed) | Keep production secrets out of developer machines; use a local `.env` for development (see REMAINING_WORK E1) |
| S4 | picksell-buyer's local `.env` has `APP_DEBUG=true` but `APP_URL=https://api.pick-sell.shop` | Low | env inspection | Fine locally. Never deploy with this file; `.env.production.example` correctly sets `APP_DEBUG=false` |
| S5 | No `config/cors.php` in either Laravel app (framework defaults apply) | Info | file check | Only matters for the Flutter **web** build; mobile apps don't use CORS |
| S6 | Logged exceptions include SQL bindings (e.g. addresses) | Low | `storage/logs/laravel.log` QueryException entries | Acceptable for development; restrict log access in production |
| S7 | Legacy `pickrush/backend` (rider registration and OTP endpoints) is still in the rider repo | Low | unused by the app | Remove or archive it with the owner's approval, so it isn't deployed by mistake |

## 4. Data integrity (local `picksell` database, read-only)

| Check | Result |
|---|---|
| Foreign-key checks enabled | yes |
| Orders without buyer, seller or product; buyer not role=buyer | 0 / 0 / 0 / 0 |
| Order status differs from its last history row | 0 |
| Picksell parcels without an order; orders with more than one parcel | 0 / 0 |
| Parcel status differs from its last ledger event | 0 |
| Duplicate scan idempotency keys | 0 |
| Assignments without a parcel or rider | 0 / 0 |
| Completed deliveries without COD; parcel COD ≠ order amount | 0 / 0 |
| Completed orders without financial rows | 0 |
| Negative stock; cart lines of non-buyers | 0 / 0 |
| **Order behind its parcel** | **2** (orders 5 and 24, see the reconciliation report) |
| **Pickrush history rows crediting a website account** | **2** (rows 127 and 128) |
| **Orders at ready_for_pickup or later without a parcel** | **10** (8 demo orders 9–16; real orders 22 and 23 stranded since 2026-10-09) |
| Orders in a legacy status | 2 (orders 1 `processing`, 2 `shipped`) |
| Orders without any history row | 4 (orders 1–4, created before history existed) |
| `jobs` / `failed_jobs` | 0 / 0 (nothing is queued; all processing is synchronous) |

**Transactions:** a scan and its order sync are separate commits by design. A failed sync never
undoes a scan, raises an admin alert, and can now be repaired with
`pickrush:reconcile-order`. Order placement, cancellation (stock return) and the order sync each
lock the order row (`lockForUpdate`) inside a transaction.

## 5. Schema notes (no migration proposed)

- `orders.status` enum still contains `in_transit`, which the lifecycle doesn't use (0 rows). Removing it is a migration; leave it until the business decides.
- `order_status_histories.changed_by` → `users` (`ON DELETE SET NULL`) is correct as designed. The defect was in the writer, not the schema.
