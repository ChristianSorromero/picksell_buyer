# Test and verification report

Phase 3 stabilization, 2026-11-01 to 2026-11-02, Windows 11, PHP 8.4.26, MySQL 8.0.45, Flutter
stable.

## 1. Automated tests

| Suite | Command | Environment | Before Phase 2 | Final |
|---|---|---|---|---|
| Picksell (feature/buyer-app-api) | `php vendor/bin/phpunit` | in-memory SQLite (`phpunit.xml`) | 446/446 | **451/451** (4,124 assertions) |
| Picksell (`production` branch, b36b37d) | same, in an isolated worktree | in-memory SQLite, `APP_URL=https://pick-sell.shop` like the main `.env` | — | **418/418** (417/418 with `APP_URL=http://localhost`, see §4) |
| picksell-buyer API | `php artisan test` | in-memory SQLite with the website schema copy | 28/28 | **28/28** (270 assertions) |
| Buyer Flutter | `flutter analyze`; `flutter test` | | no issues; 30/30 | see §5 |
| Rider Flutter | `flutter analyze`; `flutter test` | | 8 infos; 11/11 | see §5 |

`php artisan test` can't start in Picksell (`.env` DB password rejected while the app boots), so
`php vendor/bin/phpunit` was used. It applies `phpunit.xml`'s SQLite settings. There's no config
cache (`bootstrap/cache` holds only `packages.php`/`services.php`), so the tests never touch MySQL.

### Tests added (Picksell)

| Test | What it proves |
|---|---|
| `Pickrush/StaffScanOrderSyncTest::test_station_staff_and_rider_scans_carry_the_order_to_delivered_and_the_buyer_sees_each_step` | Signed-in station staff (one ID with no user, one ID equal to the buyer's) → `/station/receiving`, `/station/dispatch`; rider API accept, load, start, arrive, deliver; the buyer API reads sorted/in_transit → assigned/in_transit → out_for_delivery → delivered/to_rate; history `changed_by` NULL; no sync alert |
| `…::test_website_users_are_still_credited_and_staff_never_are` | A buyer is still credited; a staff session isn't |
| `Pickrush/ReconcileOrderTest` (3 tests) | Dry run changes nothing; `--apply` replays the missed scans at their original times, uncredits the user, logs once; a rerun is a no-op; an unknown order is refused |

Proof that the regression test catches the bug: with the `Order.php` fix removed, both
StaffScanOrderSync tests fail at the production symptom (`at_sorting_center` instead of
`sorted`; staff credited as user 1).

## 2. Live local verification (servers on a disposable database)

- **Database:** `picksell_stabilization`, a `mysqldump --single-transaction` copy of `picksell`. The original was only read.
- **Servers:** Picksell on `127.0.0.1:8001` (marketplace), with `Host: localhost:8001` serving the Pickrush portal. The picksell-buyer API on `127.0.0.1:8002`.
- **Configuration:** process environment variables override the DB name and password, `APP_ENV=local`, `SESSION_DOMAIN`, `PICKRUSH_DOMAIN` and `MAIL_MAILER=log`. No `.env` was edited and no email was sent.
- **Test accounts:** created only in the copy (`stab.*@example.test`): a seller, a buyer, a dispatcher at Cebu City Station (hub 887) and a rider there.

| Check | Result |
|---|---|
| Both servers `/ping`, catalog, Pickrush portal login page | 200 |
| Full journey repeated unattended, order 27 (final run) | ✅ all 10 steps; deliver and retry 200; 1 delivered event; 1 proof file |
| Full journey, order 26: app checkout → seller pack and handover → station receive and dispatch → rider accept, load, start (×2), arrive, deliver (×2) → seller confirm → buyer rate | ✅ every step; both buyer APIs agree at each step (table in END_TO_END_WORKFLOW_MATRIX §1) |
| Staff attribution live (staff 14 has the same ID as a real user in the copy) | ✅ all Pickrush history rows `changed_by` NULL |
| Retries | ✅ start and deliver repeated with the same key: one event each |
| Buyer app's own Dart `OrderService` against `/api` and `/api/mobile` | ✅ order 26 Completed, 10-step timeline, parcel Delivered; order 25 in the Out for Delivery tab |
| Rider app's own Dart `AuthService`/`RiderTaskService` | ✅ login, dashboard, batches, options, notifications; ❌ earnings 404 |
| Negative access probes (16) | ✅ all refused (401/403/404/redirect); details in the security report |
| `pickrush:reconcile-order 5 24` dry run, then `--apply`, then a rerun, on the copy | ✅ as expected (reconciliation report §5) |
| Public catalog parity, `/api` against `/api/mobile` | ✅ identical except image host |

Temporary Dart test files used for the APP-LIVE checks were deleted afterwards. The repos show no
leftovers.

## 3. Verification levels

| Level | Covered |
|---|---|
| Automated (PHPUnit, Flutter tests) | everything in §1 |
| Local live HTTP, real servers and DB copy | buyer API, seller web actions, station portal actions, rider API, reconciliation command |
| Local app service layer (Dart) against live servers | buyer orders and tracking; rider dashboard, batches, earnings |
| **Not done** | clicking through the Flutter UI on a device or in Chrome (no browser automation in this session); the admin UI live (the only admin is a real account and its password wasn't touched); province line-haul trips live (covered by automated tests); anything on `pick-sell.shop` or the other PC |

## 4. Failures seen and their causes

| Failure | Pre-existing? | Cause | Outcome |
|---|---|---|---|
| `php artisan test` in Picksell: "Access denied" | yes | stale DB password in Picksell `.env`; the app queries the DB while booting (`AppServiceProvider`, `PolicySettings::load`) | ran `vendor/bin/phpunit` instead; env item E1 |
| `production` worktree: 6 → 159 → 1 failures | environment | (a) junctioned `vendor/` autoloaded the main checkout's `app/`; (b) no `APP_KEY`; (c) no built Vite assets; (d) `APP_URL` http vs https | fixed each setup issue; 418/418 with the main checkout's `APP_URL` |
| `PortalAccessTest` depends on `APP_URL` scheme | yes (both branches) | `phpunit.xml` doesn't pin `APP_URL`; tests inherit the developer's `.env` | Low: pin `APP_URL` in `phpunit.xml` (not changed) |
| My own test drafts: wrong history order, sticky `withHeaders`, a guard kept between requests | introduced and fixed during Phase 2 | test harness | fixed |

## 5. Flutter

| App | `flutter analyze` | `flutter test` |
|---|---|---|
| Buyer | No issues found | 30/30 passed |
| Rider | 8 issues, all `info` level | 11/11 passed |

No Dart source was changed in either app during stabilization. The rider app's 8 infos are deprecation and style notices
(`withOpacity`, `value`, an unnecessary import, one `const`), not errors.
