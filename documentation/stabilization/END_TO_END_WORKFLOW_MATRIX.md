# End-to-end workflow matrix

Phase 3 stabilization, 2026-11-01. Each workflow is marked by its evidence:

- **LIVE**: run over HTTP against local servers on the disposable copy `picksell_stabilization`, using the same endpoints and payloads as the apps and web forms (`e2e.sh`, `e2e_finish.sh`, `authz.sh` in the session scratchpad).
- **APP-LIVE**: the Flutter app's own Dart service and model classes run against those servers.
- **TEST**: automated tests only.
- **STATIC**: code reading only.

No Flutter UI was clicked through; the UI layer has its own widget tests.

## 1. The verified journey (LIVE, order 26 on the copy)

| # | Actor and action | Client → endpoint | Server code | DB result | Buyer sees (`/api` and `/api/mobile`) |
|---|---|---|---|---|---|
| 1 | Buyer logs in, adds to cart, checks out (COD) | buyer app → `POST /api/login`, `POST /api/buyer/cart`, `POST /api/buyer/checkout` | `MobileAuthController@login`, `Api\CartController@store`, `Api\CheckoutController@place` → `OrderPlacement::place` | `orders` row `placed`, history (buyer 78), stock 13→11 | placed / To Ship |
| 2 | Seller packs | web `PATCH /seller/orders/{id}/pack` | `SellerController@packOrder` → lifecycle | `preparing`, history (seller 77) | preparing / To Ship |
| 3 | Seller hands over | web `PATCH /seller/orders/{id}/handover` | `SellerController@handoverOrder` → `PicksellBridge::book` → `ParcelRegistrar` | `ready_for_pickup`; `pr_parcels` waiting_pickup, waybill = tracking no. | ready_for_pickup / To Ship |
| 4 | Station staff receive the walk-in | Pickrush portal `POST /station/receiving` (pickrush guard, staff 14) | `Station\ReceivingController@scan` → `StationReceiving::scan` → `ParcelLedger::record` → `ParcelStatusChanged` → `SyncOrderWithParcel` | parcel at_origin_hub; order picked_up → at_sorting_center, history `changed_by` NULL | at_sorting_center / In Transit |
| 5 | Station dispatches to a rider | portal `POST /station/dispatch` | `Station\DispatchController@assign` → `DispatchService` | parcel assigned_to_rider; order → sorted → assigned_to_rider (same-city skip) | assigned_to_rider / In Transit |
| 6 | Rider accepts and loads | rider app → `POST /api/rider/batches/{b}/accept`, `/load` | `RiderBatchController` → `RiderBatches`, `DeliveryRoutes::load` | `loaded_at` set; **no status change** (by design) | assigned_to_rider / In Transit |
| 7 | Rider starts the route (sent twice with one key) | `POST /api/rider/batches/{b}/start` | `DeliveryRoutes::startRoute` → `RiderTaskService::startDelivery` | parcel out_for_delivery (1 event); order out_for_delivery | out_for_delivery / Out for Delivery |
| 8 | Rider arrives and delivers (COD and photo, sent twice) | `POST …/stops/arrive`, `POST …/deliveries/{a}/deliver` (multipart) | `DeliveryRoutes::deliver` → `RiderTaskService::deliver` | parcel delivered (1 event), `cod_collected` 900.00, proof on the private disk; order delivered | delivered / To Rate |
| 9 | Buyer tries to cancel | `POST /api/buyer/orders/{id}/cancel` | `OrderController@cancel` | refused, **409** | unchanged |
| 10 | Seller confirms delivery | web `PATCH /seller/orders/{id}/confirm-delivery` | `SellerController@confirmDelivery` → lifecycle + `FinancialLedgerService` | completed, history (seller 77) | completed / To Rate |
| 11 | Buyer rates | `POST /api/buyer/orders/{id}/rate` | `OrderController@rate` | rating plus one `product_reviews` row | completed / Completed |

- **Notifications:** the buyer received the database notifications "Ready for pickup", "Out for delivery" and "Delivered".
- **Skipped messages are by design:** walk-in and same-city parcels skip "picked up" and "sorted", so those messages aren't sent.
- **Alerts:** no `pickrush.sync_failed` alert was raised.
- **APP-LIVE (buyer app):** the app's `OrderService` against both `/api` and `/api/mobile` read order 26 as Completed with the full ten-step timeline and the "Delivered" parcel. It also listed order 25 in the Out for Delivery tab.
- **APP-LIVE (rider app):** the app's `AuthService` and `RiderTaskService` read the dashboard, batches, options and notifications. Earnings failed with 404.

## 2. Buyer

| Function | Trace | Evidence |
|---|---|---|
| Registration (email code → details plus ID → pending → admin approval) | app `register` → `/api/register/*` → `MobileAuthController` → `users` (pending) | TEST (`RegistrationTest`, both APIs), STATIC |
| Login, token, logout | `/api/login`, `/api/buyer/logout` → Sanctum `personal_access_tokens` | LIVE (login) |
| Browse, details, reviews, search | `/api/home`, `/products`, `/products/{id}`, `/search-suggestions` → `CatalogController` | LIVE (data identical on both APIs) |
| Cart, quote, checkout (COD) | see §1 | LIVE |
| History, tabs, detail, tracking | `/api/buyer/orders[/{id}]` → `BuyerPresenter::orderCard/orderDetail/tracking` | LIVE, APP-LIVE |
| Cancel | `/buyer/orders/{id}/cancel` → `OrderCancellationService` (placed/confirmed/preparing) | LIVE (refused after dispatch), TEST |
| Rate, review | §1 step 11 | LIVE |
| Returns, complaints | `/buyer/orders/{id}/return`, `/report` → `return_requests`, `complaints` | TEST (`OrderFlowTest`, `ReturnRefundWorkflowTest`) |
| Buyer website | `routes/web.php` buyer group → `BuyerController` (same `orders` rows) | TEST (`BuyerOrderStatusTest`, `CheckoutTest`) |

**Web and app consistency:** both read `orders.status` and the same Pickrush events. The website
shows the parcel enum labels; the picksell-buyer API words three line-haul labels slightly
differently (see the API matrix).

## 3. Seller

| Function | Trace | Evidence |
|---|---|---|
| Login, approved-seller gate | web login → `SellerMiddleware` | LIVE |
| Products, images, stock | `SellerController`, `SellerProductImageController` → `products`, `product_images` | TEST (`SellerWorkflowTest`, `ProductImageTest`, `SellerInventorySortingTest`) |
| Incoming orders → pack → hand over → confirm delivery | §1 steps 2, 3, 10 | LIVE |
| Another seller's order | `GET`/`PATCH /seller/orders/5…` | LIVE: **403** |
| Reports, commission | `/seller/reports`, `FinancialLedgerService` at confirm | TEST (`AdminCommissionReconciliationTest`) |

## 4. Superadmin

| Function | Trace | Evidence |
|---|---|---|
| Admin portal access | `AdminMiddleware` + `Permission` gates (`routes/web.php` `admin` group) | LIVE: seller → redirect away; Pickrush staff session → login. TEST (`AdminAuthorizationTest`, `AdminOperationAuthorizationTest`) |
| Registration approvals, suspension | `AdminRegistrationController`, `UserModerationService` → `users`, `user_status_histories` | TEST (`AdminRegistrationQueueTest`, `UserAccountModerationTest`) |
| Orders: override, resolve, cancel (cancels the parcel) | `AdminOrderController` → `OrderAdministrationService` → `PicksellBridge::cancel` | TEST (`AdminOrderControlTest`, `PicksellBridgeTest`) |
| Complaints, returns, refunds, reports, audit | `Admin*Controller` → services | TEST |
| One superadmin | `users`: exactly one account with role admin | DB read-only |

The admin UI was not exercised live, because the only admin account is real and its password
isn't known. That account was not changed.

## 5. Pickrush logistics

| Function | Trace | Evidence |
|---|---|---|
| Staff login (separate guard and cookie) | portal `POST /login` → `Auth::guard('pickrush')` | LIVE |
| Station receiving (walk-in, rider drop, inbound trip) | `Station\ReceivingController` → `StationReceiving` | LIVE (walk-in), TEST (`StationOperationsTest`) |
| Destination arrival → order "sorted" | inbound at the destination station → `arrived_at_station` | TEST (`StaffScanOrderSyncTest`, as signed-in staff) |
| Province sorting, trips, manifests | `Province\*Controller` → `Sorting`, `ManifestService` | TEST (`ProvinceOperationsTest`) |
| Dispatch to a rider | `Station\DispatchController@assign` | LIVE |
| Failed deliveries, return to sender, exceptions | `FailedDeliveries`, `ExceptionDesk` | TEST. See the lifecycle gap in the reconciliation report. |
| Ledger history | `pr_parcel_events` (append-only) | LIVE, DB |

## 6. Rider

| Function | Trace | Evidence |
|---|---|---|
| Apply, email code, station approval | `/api/rider/email-code/*`, `/apply` → `RiderApplication`; station `RiderController` | TEST (`RiderApplicationTest`) |
| Login and session | `/api/rider/login` → `pr_rider_tokens` (hashed, no expiry) | LIVE |
| Pickup batches (seller pickups, hub hand-over) | `/batches/{b}/pickups`, `/hub/arrive` → `RiderBatches` | TEST (`RiderBatchTest`) |
| Delivery batches: accept, load, start, arrive, deliver or fail | §1 steps 6–8 | LIVE (deliver), TEST (fail: `DeliveryBatchTest`) |
| COD and proof | `cod_confirmed` must equal the parcel COD; photo on the private `local` disk | LIVE |
| Cash remittance and batch closing | station `CashController` → `CashHandling` | TEST. On this branch, a finished delivery batch stays "accepted" after remittance (batches 3 and 4 on the copy). `production` adds the batch re-sync. |
| Earnings, change password, forgot password | `/api/rider/earnings`, `/password*` | **FAIL on this branch** (404). Present on `production`. |
