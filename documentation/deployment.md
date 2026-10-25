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
Start from `.env.example`. Required production values:

| Setting | Value |
|---|---|
| `APP_ENV` / `APP_DEBUG` | `production` / `false` |
| `APP_KEY` | Generated once (`php artisan key:generate`) and kept secret. Losing it invalidates sessions and encrypted data. |
| `APP_URL` | The public `https://` URL |
| `LOG_LEVEL` | `warning` or `error` |
| `DB_*` | A least-privilege MySQL user limited to the Picksell schema, never root |
| `SESSION_SECURE_COOKIE` | `true` |
| `MAIL_*` | A real SMTP provider. With `log`, buyers never receive verification or reset codes. |
| `QUEUE_CONNECTION` | `database` plus a worker is recommended. With `sync`, mail is sent inside web requests. |
| `PICKSELL_RIDER_PAY_STATUS` | `unconfigured` until rates are approved |
| `PICKSELL_WITHHOLDING_ENABLED` | `false` until professionally reviewed |

**Secrets** (`APP_KEY`, the DB password, SMTP credentials) live only in the
server's environment or secret store. Never commit them. Note: commit
`9dda404` on GitHub contains an old `.env` with the MySQL root password,
which has since been rotated. Don't reuse it anywhere.

**Display timezone:** the app runs in UTC, so times on web pages show UTC.
Decide whether to set `APP_TIMEZONE=Asia/Manila` *before* production data
exists; changing it later shifts how stored timestamps are read.

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
- **Scheduler:** cron `* * * * * php artisan schedule:run`. It runs
  `picksell:settle-orders` daily and `sanctum:prune-expired`. Alert if
  settlement hasn't run for 2 days.
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
- the web buyer has no return-request screen (returns are app-only)
