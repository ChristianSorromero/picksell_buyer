# Remaining work and approvals

Phase 3 stabilization, 2026-11-01. Items marked **Owner** need a decision before anyone acts.

## Decisions needed now

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | **Reconcile the two Picksell branches.** `production` (b36b37d, ChristianSorromero, Oct 30) has the rider earnings and password endpoints, batch-closing fixes and the same actor fix. `feature/buyer-app-api` has the wishlist and recently-viewed commit and the uncommitted `/api/mobile` work. | merge `production` into the feature branch, or the reverse; or cherry-pick b36b37d | Commit the `/api/mobile` work first, then merge `production` in. `Order.php` will conflict on the comment only; keep either version. |
| D2 | **Repair real orders 5 and 24 and history rows 127 and 128** with `pickrush:reconcile-order 5 24 --apply` | apply / don't apply | Apply after a `mysqldump`. It was rehearsed on the copy with the exact expected result (reconciliation report §5–6). |
| D3 | **Order 25 on the other PC** | run the dry run there | Dry run first; apply only if it matches the 5/24 pattern |
| D4 | **Orders 22 and 23** (real, `ready_for_pickup` since Oct 9, legacy waybills, no Pickrush parcel) | book them with Pickrush (`PicksellBridge::book`), or cancel them through the admin | Ask the seller whether the items still exist |
| D5 | **One buyer API** | Picksell `/api/mobile` or picksell-buyer `/api` | Picksell `/api/mobile` (API matrix §5) |
| D6 | **Cart badge meaning** | number of lines (website, `/api/mobile`) or total quantity (picksell-buyer `/api`) | Lines, to match the website |
| D7 | **Returns before the destination station** (lifecycle gap) | allow `at_sorting_center`/`sorted → returned` in `OrderLifecycleService` | Allow it, mirrored in both copies, with a test |
| D8 | **Commit this work** (see "Git" below) | | |

## Open issues by severity

| # | Issue | Severity | Codebase | Impact | Action | Owner? |
|---|---|---|---|---|---|---|
| R1 | Orders 5 and 24 behind their delivered parcels; rows 127 and 128 credit a buyer | High | data | The buyer sees "In Transit" for delivered goods; the seller can't confirm; no commission posted | D2 | Owner |
| R2 | Rider app calls `/api/rider/earnings`, `/password`, `/password/forgot`, `/password/reset`, which don't exist on the checked-out branch | High | Picksell (branch) | Earnings tab and password screens fail (verified live: 404) | D1 | Owner |
| R3 | A finished delivery batch stays "accepted" after cash remittance on this branch | Medium | Picksell (branch) | The rider's batch list keeps finished work | D1 (fix is in `production`) | Owner |
| R4 | Two hand-maintained buyer APIs | Medium | both | Rules can drift (4 small differences today) | D5; meanwhile run `scripts/check-website-drift.php` | Owner |
| R5 | Picksell local `.env` holds production settings and a stale DB password | Medium | Picksell env | The website, Pickrush portal and rider API can't start locally without an override; `php artisan test` can't boot | E1 | Owner |
| R6 | Orders 22 and 23 stranded without a parcel | Medium | data | Never delivered | D4 | Owner |
| R7 | Parcel returned before the destination station can't move its order to `returned` | Medium | both lifecycles | Order stuck plus an admin alert | D7 | Owner |
| R8 | ID uploads and evidence on the public disk | Medium | Picksell | Anyone with a URL can open them | website change | Owner |
| R9 | Rider tokens don't expire | Low | Picksell | A stolen token stays valid | add an expiry | no |
| R10 | `in_transit` order status half-supported | Low | Picksell, DB | none today (0 rows) | decide drop or map | Owner (schema) |
| R11 | `SyncOrderWithParcel`: a notification failure after a successful move raises a misleading alert | Low | Picksell | Misleading admin alert | move `notify()` outside the `try` | no |
| R12 | Default-guard actor fallback in 5 other writers | Low (latent) | Picksell | none today | same `instanceof User` check | no |
| R13 | Tracking label wording differs between the APIs; images point at `pick-sell.shop` from the buyer API | Low | picksell-buyer | Cosmetic, or broken images if the public site is down | use the enum label; set `PICKSELL_PUBLIC_STORAGE_URL` per environment | no |
| R14 | Dead app method `CatalogService.shippingOptions()` calls a missing endpoint | Low | buyer app | none | remove when convenient | no |
| R15 | Legacy `pickrush/backend` folder | Low | rider repo | confusion or accidental deploy | archive | Owner |
| R16 | Rider repo has an uncommitted Gradle wrapper upgrade (8.12 → 9.7.1, made 2026-11-01 00:47, before this session) | Info | rider repo | Unreviewed build change | keep or revert | Owner |
| R17 | Orders 1 and 2 in legacy statuses; demo orders 9–16 | Low | data | Display only | admin tidy-up | Owner |
| R18 | `DeliveryRoutes::deliver` stores the proof photo before the last refusable check (COD limit) and outside the transaction | Low | Picksell | A refused or interrupted delivery leaves an orphan photo file. Seen once in this run, when a client request was cut off mid-delivery. | Store the photo after `RiderTaskService::deliver` succeeds, or delete it on refusal | no |
| R19 | Tests depend on the developer's `.env` `APP_URL` (`PortalAccessTest` expects `https://…`) | Low | Picksell (both branches) | A suite fails on a fresh checkout | Pin `APP_URL` in `phpunit.xml` | no |

## Environment (E)

**E1. Picksell local environment.** The `.env` in `C:\projects\Picksell` targets the local
MySQL `picksell` database, but:
- its password no longer matches (the MySQL root password was reset on this PC on 2026-11-01);
- `APP_ENV=production`, `APP_URL=https://pick-sell.shop` and `SESSION_DOMAIN=.pick-sell.shop` break local logins;
- it holds real SMTP credentials.

Nothing was changed. To run locally without editing it, set process environment variables (as
this session did: `DB_DATABASE`, `DB_PASSWORD`, `APP_ENV=local`, `SESSION_DOMAIN=null`,
`PICKRUSH_DOMAIN=localhost`, `MAIL_MAILER=log`). Better: keep this file for the server and give
developers a local `.env`. **Owner:** confirm whether this PC ever serves `pick-sell.shop`
(nothing was running here during the session).

**E2. Disposable database** `picksell_stabilization` (MySQL, local) holds a copy of `picksell`
from 2026-11-01 plus test accounts that exist only there (`stab.seller@`, `stab.buyer@`,
`stab.dispatcher@`, `stab.rider@example.test`), test
orders 25 and 26, and the rehearsed repair of orders 5 and 24. It's safe to drop
(`DROP DATABASE picksell_stabilization;`); the owner decides.

## Git

| Repo | Branch | Changes from this work | Pre-existing, not touched |
|---|---|---|---|
| Picksell (remote: justinplantilla/Picksell) | feature/buyer-app-api | `app/Models/Order.php` (actor fix); new `app/Pickrush/Console/Commands/ReconcileOrder.php`; new `tests/Feature/Pickrush/StaffScanOrderSyncTest.php`, `ReconcileOrderTest.php` | uncommitted `/api/mobile` port (BuyerApi controllers, routes, Sanctum config and migration, `composer.json`/`.lock`, `User.php`, `ReturnRequest.php`, `BuyerController.php`, `bootstrap/app.php`, `routes/api.php`, `PaeteRiderSeeder.php`, tests) |
| picksell-buyer | feature/shared-database | `app/Models/Order.php` (actor fix); `scripts/check-website-drift.php`; `documentation/stabilization/*` | none |
| pickrush | main | none | Gradle wrapper change; generated plugin files (line endings only, from `flutter pub get`) |

**Not committed.** Picksell has ambiguous uncommitted work from before this session, so nothing
there was staged; the owner chooses the commit grouping (D8). Proposed Picksell commits: (1) the
`/api/mobile` port as its owner intends; (2) "Never credit Pickrush staff as a website user in
order history", with `Order.php` and `StaffScanOrderSyncTest`; (3) "Add pickrush:reconcile-order",
with the command and its test. picksell-buyer: one commit for the actor fix, one for the drift
script and the stabilization docs. Nothing has been pushed.
