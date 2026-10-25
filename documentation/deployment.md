# Deployment and release runbook

Picksell has **not** been deployed to production. This is the checklist and
procedure for a controlled first release. Run commands from the repository
root, with PHP 8.4 (`composer.lock` requires PHP 8.4.1 or later).

## 1. Release gate
1. CI is green on the release commit (`.github/workflows/ci.yml`: Laravel
   tests, `composer audit`, `flutter analyze`, `flutter test`).
2. `php artisan picksell:preflight` exits 0 on the production server. It
   checks:
   - `APP_ENV`, `APP_DEBUG`, `APP_KEY`, an https `APP_URL`, the log level
   - secure cookies, token expiry, a non-root database user
   - real mail
   - pending migrations, ledger balance
   - COD-only payment methods
3. Business decisions in `finance-returns-payouts.md` §8 are signed off, or
   left at their safe defaults: rider pay unconfigured, withholding off.

## 2. Production configuration
Start from **`.env.production.example`**. It lists every production
setting, with secrets left blank. `.env.example` stays the local
development template: http, the emulator address, mail to the log.

### Where each value lives
- **Hosting platform's secret store** (never in a file in the
  repository):

  | Setting | Notes |
  |---|---|
  | `APP_KEY` | Generate once on the server (`php artisan key:generate --show`) and keep it. Changing it logs everyone out and breaks encrypted values. |
  | `DB_PASSWORD` | — |
  | `MAIL_USERNAME`, `MAIL_PASSWORD` | — |
  | Any future error-tracking DSN or push credentials | — |

- **Hosting platform's environment** (not secret, but specific to the
  deployment):

  | Setting | Value |
  |---|---|
  | `APP_URL` | The public `https://` address |
  | `DB_HOST` | — |
  | `MAIL_HOST` | — |
  | `MAIL_FROM_ADDRESS` | On your real domain |

- **Safe to keep as in the template:**

  | Setting | Value |
  |---|---|
  | `APP_ENV` / `APP_DEBUG` | `production` / `false` |
  | Logging | `LOG_LEVEL=warning`, `LOG_STACK=daily` |
  | `DB_USERNAME` | `picksell_app`, least-privilege, never root |
  | `DB_TIMEZONE` | `+00:00` |
  | Cache, sessions, queue | `CACHE_STORE`, `SESSION_DRIVER` and `QUEUE_CONNECTION` all `database` |
  | `SESSION_SECURE_COOKIE` | `true` |
  | Time zones | `APP_DISPLAY_TIMEZONE` and `APP_SCHEDULE_TIMEZONE` both `Asia/Manila` |
  | Finance policies | All at their safe defaults: rider pay `unconfigured`, withholding `false`, two-person rule `false` |

`.gitignore` ignores every `.env.*` file except the two templates, so a
filled-in `.env.production` can't be committed by accident.

**Verified in a safe environment (2026-10-26).** `picksell:preflight` was
run with the template's values against the development database. It's
read-only and no secrets were printed.
- Passed: `APP_ENV`, `APP_DEBUG`, `LOG_LEVEL`, `SESSION_SECURE_COOKIE`,
  mail driver, UTC storage, non-root DB user, MySQL session in UTC,
  ledger balanced, no pending migrations.
- The only blockers left are the two values only the owner can supply:
  `APP_URL` (the real domain) and `MAIL_HOST` (an SMTP provider).
- Preflight rejects template placeholders (`CHANGE-ME`, `localhost`,
  `*.example`), so they can't pass by accident.

### Time zone
- **Storage stays UTC.** That includes the append-only ledger and audit
  log.
- **Philippine time (`Asia/Manila`) is used for:**
  - pages, and dates people enter
  - report and payout-period days
  - delivery estimates and rider-pay stops
  - the scheduler: settlement at 02:00 Manila
- **Code:** `App\Support\LocalTime`; views use `->forDisplay()`.
- **The mobile app** receives ISO-8601 UTC and shows device-local time.
- **Production MySQL:** set `DB_TIMEZONE=+00:00` on the first deploy.
  - Development MySQL leaves it unset, because its rows were written under
    the PC's UTC+8 session setting.
  - Preflight warns if the session time zone isn't UTC.

### Credentials exposed in Git history (assessed 2026-10-26)
- **What's exposed:**
  - The repository `ChristianSorromero/picksell_buyer` is **public**.
  - `.env` from the initial commit `9dda404` is visible on `main` today,
    because `main` has no later commits.
  - It contains `DB_USERNAME=root` and a non-empty `DB_PASSWORD` for
    `127.0.0.1:3306`. `APP_KEY` is empty.
  - No other secret files or token patterns were found in any pushed
    commit.
- **Is the old password still valid?** No. It was tested without printing
  it: MySQL rejects it for `root` and for `picksell_app` (error 1045). It
  also differs from the current app password.
- **Is MySQL reachable from outside?**
  - On the development PC MySQL listens on all interfaces, but the Windows
    firewall's default inbound block applies and no rule allows port 3306.
    So it isn't reachable from the network.
  - Recommended anyway: `bind-address=127.0.0.1` in `my.ini`.
- **Remedy, in order:**
  1. Merge `feature/buyer-mobile-app` into `main`. That removes `.env` from
     the current tree and adds the `.env.*` ignore rules.
  2. Never reuse the old password anywhere.
  3. Turn on GitHub secret scanning and push protection (repository
     Settings → Code security).
  4. *Optional, needs the owner's authorization:* purge the file from
     history with `git filter-repo --path .env --invert-paths`, then
     force-push.
     - This rewrites every commit ID, so every clone must re-clone.
     - Forks and cached views may still hold the file. GitHub Support can
       clear cached views.
     - Because the credential is already invalid, rotation plus removal
       from `main` is the essential part.

**Mobile app:** release builds must point at the https API:
```
flutter build apk --release --dart-define=API_BASE_URL=https://<domain>/api
```
The app refuses plain http in release mode.

## 3. Database migrations

| Migration | Effect | Rollback |
|---|---|---|
| `2026_10_20_000001_add_buyer_email_verification_to_users_table` | Adds columns | Reversible |
| `2026_10_21_000001_create_buyer_commerce_tables` | Adds buyer tables and order columns | Reversible before use. **Destructive** once returns, vouchers or orders exist. |
| `2026_10_25_000001_keep_order_history_when_accounts_close` | Adds `anonymized_at`, `deactivated` status; FKs → restrict | Reversible. Restores the old cascade deletes, which is unsafe. |
| `2026_10_26_000001_add_cod_payments_returns_workflow_and_ledger` | Payment fields, return case fields, ledger, payouts, audit log | **Destructive** once financial data exists (drops the ledger and audit tables) |
| `2026_10_27_000001_add_delivery_proof_refund_rules_and_finance_controls` | Delivery attempts, refund rules, tax profiles, payout dates | Reversible before use. **Destructive** for delivery proof and tax profiles afterwards. |

All five were verified on a scratch SQLite database: migrate, roll back
the last three, migrate again. On development MySQL they are applied, with
none pending.

**Production rule:** take a backup, run `php artisan migrate --force`, and
**roll forward** with a new migration if something is wrong. Never
`migrate:rollback`, `migrate:fresh`, `migrate:reset` or `db:seed` against
production financial data. The demo seeder refuses to run in production;
`DatabaseSeeder` still creates admin, seller and buyer logins with
published passwords, so don't run it there.

## 4. Backups and recovery
- **Nightly** logical backup with `mysqldump --single-transaction
  --routines` of the Picksell schema, stored off-server and encrypted, kept
  ≥30 days. Also back up `storage/app` (ID documents, return evidence,
  delivery photos) and `storage/app/public` (product images).
- **Before every release:** an extra on-demand backup.
- **Restore drill** before go-live, then quarterly:
  1. Restore into a staging database.
  2. Run `php artisan picksell:preflight` there; the ledger must balance.
  3. Spot-check that order, payout and ledger totals match.
- **Not verified:** no backup job exists yet; it must be set up on the
  hosting platform.

## 5. Monitoring and logging
- **Health check:** `GET /up` (Laravel) returns 200 when the app boots.
  Point an uptime monitor at it.
- **Scheduler:** cron `* * * * * php artisan schedule:run`. The server
  clock can be UTC. Schedules are evaluated in `APP_SCHEDULE_TIMEZONE`
  (Asia/Manila):
  - `picksell:settle-orders` at 02:00 Manila
  - `sanctum:prune-expired` at midnight Manila

  Check with `php artisan schedule:list`. Alert if settlement hasn't run
  for 2 days.
- **Queue worker** (if `QUEUE_CONNECTION=database`): a supervised
  `php artisan queue:work`.
- **Logs:** the `stack` channel. Ship them to the host's log service. Don't
  log at debug level in production (personal data).
- **Daily financial checks:** Admin → Finance. The ledger must say
  "balanced", and investigate:
  - cash held by riders for more than a day
  - returns waiting for admin
  - refunds approved but not handed over
- **Error tracking** (e.g. Sentry): recommended, not configured. It needs
  an account and a DSN secret.

## 6. Release procedure
1. Announce a maintenance window; `php artisan down --retry=60`.
2. Back up (section 4).
3. Deploy the code, then `composer install --no-dev --optimize-autoloader`.
4. `php artisan migrate --force`
5. `php artisan config:cache && php artisan route:cache && php artisan view:cache`
6. `php artisan storage:link` (first deploy only).
7. `php artisan picksell:preflight`. Stop if it reports blockers.
8. `php artisan up`, then run the smoke tests.

**Rollback:**
- Code: redeploy the previous release.
- Database: restore the pre-release backup only if a migration corrupted
  data, accepting the loss of anything written since. Prefer a
  roll-forward fix.

## 7. Post-deployment smoke tests (with test accounts, no real money)
1. `GET /up` returns 200; `GET /api/payment-methods` lists only Cash on
   Delivery.
2. Buyer app: register (email code arrives), log in, browse, add to cart,
   check out with COD. The order shows `unpaid`.
3. Seller: pack and hand over. Logistics: scan and assign. Rider: out for
   delivery, then deliver with the exact cash and a recipient name. The
   order shows `collected`.
4. Logistics Cash Desk: confirm the hand-in. The order shows `paid`.
   Finance shows the ledger balanced.
5. Password reset email arrives; a wrong code is refused.
6. Cancel or void the test order and data according to the operating
   procedure. Don't settle or pay out test orders.

## 8. Known gaps before production
See the readiness assessment in the latest progress report. In particular:
- the Rider app API isn't implemented
- push notifications
- automated backups and error tracking
- BIR Form 2307 / withholding reporting
- combination-level variant stock
- the real domain and SMTP provider (the two remaining preflight blockers)
