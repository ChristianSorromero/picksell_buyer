# PickSell stabilization: master report

Phase 3, 2026-11-01 to 2026-11-02. Covers the three codebases:

| Codebase | Path | Branch | Role |
|---|---|---|---|
| Picksell | `C:\projects\Picksell` | `feature/buyer-app-api` | website, Pickrush logistics, rider API, buyer API port (`/api/mobile`) |
| picksell-buyer | `C:\projects\picksell-buyer\picksell-buyer` | `feature/shared-database` | buyer Flutter app and its own buyer API (`/api`) |
| pickrush | `C:\projects\pickrush\pickrush` | `main` | rider Flutter app (calls Picksell `/api/rider/*`) |

Companion documents in this folder: CROSS_SYSTEM_API_MATRIX, END_TO_END_WORKFLOW_MATRIX,
ORDER_PARCEL_RECONCILIATION_REPORT, SECURITY_AND_DATA_INTEGRITY_REPORT,
TEST_AND_VERIFICATION_REPORT, REMAINING_WORK_AND_APPROVALS.

## 1. Executive summary

**Result: partially stabilized.**

- **Core flow works locally.** Buyer checkout → seller → Pickrush station → rider → delivery → seller confirmation → buyer rating ran end to end on real local servers against a copy of the database. Both buyer APIs and the buyer app's own service layer reported the correct status at every step.
- **The defect behind the original report is fixed and guarded by tests.** Pickrush staff were written into `order_status_histories.changed_by`, which froze orders behind their parcels.
- **The two real orders it froze (5 and 24)** have a tested repair command, rehearsed successfully on the copy. Running it on the real database is waiting for approval.
- **Biggest remaining risk: Picksell's branches have diverged.** The checked-out branch lacks four rider endpoints the rider app uses: earnings, change password, forgot password and reset password (404 live). It also lacks a batch-closing fix. Both exist on `production`, which passes its own 418 tests.
- **Picksell can't run locally with its current `.env`** (production settings, stale DB password). This session used process-environment overrides instead of editing it.

## 2. Baseline and final condition

| | Baseline (start of Phase 3) | Final |
|---|---|---|
| Actor fix | present in both `Order.php` (uncommitted) | unchanged, re-verified (tests + live) |
| Picksell tests | 448/448 | 451/451 |
| picksell-buyer API tests | 28/28 | 28/28 |
| Stuck real orders | 5, 24 (+ 2 wrong credits) | unchanged in the real DB; repair rehearsed on the copy |
| Picksell local run | impossible (`.env`) | possible via env override; `.env` untouched |
| Live end-to-end evidence | none | full journey verified on the copy |

## 3. Issues

### Fixed and verified

| Issue | Fix | Evidence |
|---|---|---|
| Pickrush staff credited as website users; FK failures froze orders (Phase 2) | `Order::recordStatusChange` credits only `App\Models\User` (both repos) | StaffScanOrderSyncTest (fails without the fix); live run with a colliding staff ID |
| No safe way to repair orders left behind | new `pickrush:reconcile-order` (dry run by default, original timestamps, audit, idempotent) | ReconcileOrderTest; rehearsal on the copy |
| No guard against buyer-API rule drift | new `scripts/check-website-drift.php` (read-only) | finds 4 known small differences; order rules identical |

### Verified working (no change needed)

Status vocabulary and tabs (three-way match); lifecycle and cancellation rules identical in
both APIs; parcel ledger (no duplicates, status = last event); retries are idempotent; ownership
and role boundaries (16 live probes refused); cross-API tokens; seller handover booking;
station receiving and dispatch; rider delivery with COD and proof; seller confirm with financial
posting; buyer rating and review.

### Remaining (full list in REMAINING_WORK_AND_APPROVALS)

- **High:** R1 orders 5 and 24 not yet repaired; R2 rider endpoints missing on this branch.
- **Medium:** R3 batch closing; R4 duplicate buyer APIs; R5 Picksell `.env`; R6 orders 22 and 23 stranded; R7 returns before the destination station can't close the order; R8 IDs on the public disk.
- **Low:** R9–R19.

## 4. Test results

| Suite | Result |
|---|---|
| Picksell PHPUnit | 451/451 |
| Picksell `production` branch PHPUnit (isolated worktree) | 418/418 (with the same `APP_URL` as the main checkout) |
| picksell-buyer API | 28/28 |
| Buyer Flutter analyze / test | no issues / 30/30 |
| Rider Flutter analyze / test | 8 infos (deprecations and style; 0 errors, 0 warnings) / 11/11 |

## 5. Verification limits

- **Not tested:** the Flutter UI was not clicked through, the admin UI was not used live, and line-haul trips were not run live (automated tests only).
- **Database scope:** all live work ran on a **copy** of the local database. Whether `pick-sell.shop` uses this PC's database or another machine's couldn't be determined: no tunnel or server was running here, and the domain resolves to Cloudflare.
- **Order 25** exists only on the other PC.

## 6. Data safety statement

- **Real `picksell` database:** read-only queries only. **No row was inserted, updated or deleted.**
- **Writes:** only in `picksell_stabilization`, created for this work.
- **Config:** no `.env` was edited, no migration was run, and no email was sent (`MAIL_MAILER=log`).
- **Files:** proof uploads for test orders in the copy put four synthetic images (plain-colour JPEGs, gitignored storage) under `C:\projects\Picksell\storage\app\private\pickrush\proof\3`, `…\4` and `…\5`. One of them, in `proof\4`, is an orphan from an interrupted request (see R18). The `proof\2` files are pre-existing October data.

## 7. Release readiness

| Category | Status | Why |
|---|---|---|
| Functional correctness | CONDITIONAL | Core flow verified live; rider earnings and password features fail on the checked-out branch |
| Cross-system integration | CONDITIONAL | Order and parcel sync fixed and verified; two buyer APIs must be kept in step by hand |
| Database integrity | FAIL | Two real orders behind their parcels, two wrong credits, two stranded orders (repair awaits approval) |
| Authentication and authorization | PASS | Guards separated; 16 live negative probes refused; admin authorization covered by tests |
| Order and parcel consistency | CONDITIONAL | Fixed going forward; gap for returns before the destination station |
| Buyer tracking accuracy | PASS | Identical status and tab on both APIs and in the app's service layer at every step |
| Rider delivery reliability | CONDITIONAL | Delivery flow verified; batch closing and earnings need the `production` changes |
| Seller operational reliability | PASS | Pack, handover and confirm verified live; ownership enforced |
| Superadmin control integrity | CONDITIONAL | Automated tests only; one admin account confirmed |
| Test coverage | PASS | 451 + 28 + Flutter suites; regression tests for both fixes |
| Environment reproducibility | FAIL | Picksell `.env` unusable locally; tests depend on the developer's `APP_URL` |
| Git cleanliness | BLOCKED | Picksell has large uncommitted pre-existing work; branches diverged (owner decision) |
| Deployment readiness | BLOCKED | Which branch and database are live is unknown; not production-ready until D1, D2 and E1 are settled |

**Not production-ready.** The next step is decision D1 in REMAINING_WORK_AND_APPROVALS (commit
the `/api/mobile` work, then merge `production`), followed by D2 (repair orders 5 and 24).
