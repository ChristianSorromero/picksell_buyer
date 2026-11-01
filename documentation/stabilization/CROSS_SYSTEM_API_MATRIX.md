# Cross-system API matrix

Phase 3 stabilization, 2026-11-01. Routes come from the route files. The live checks ran
against local servers on the disposable database copy (Picksell on `127.0.0.1:8001`, the
picksell-buyer API on `127.0.0.1:8002`).

## 1. Who serves what

| API | Codebase | Routes | Auth | Consumer |
|---|---|---|---|---|
| Buyer app API | picksell-buyer | `routes/api.php` → `/api/*` | Sanctum bearer token (`auth:sanctum`, `active.buyer`) | Buyer Flutter app (the app's default `API_BASE_URL` is `http://10.0.2.2:8000/api`, the same shape) |
| Buyer app API, port | Picksell (uncommitted) | `routes/buyer-api.php` → `/api/mobile/*` | Sanctum bearer (`auth:sanctum`, `buyer.api`) | The buyer Flutter app, when built with `API_BASE_URL=…/api/mobile` |
| Rider API | Picksell | `routes/pickrush-api.php` → `/api/rider/*` | Own hashed bearer tokens (`pr_rider_tokens`, `pickrush.rider[:active]`) | Rider Flutter app (`BASE_URL`, default `https://pick-sell.shop`) |
| Website | Picksell | `routes/web.php` | Session, `web` guard (users) | Browsers: buyer, seller and admin portals |
| Pickrush portal | Picksell | `routes/pickrush.php`, on host `config('pickrush.domain')` | Session, `pickrush` guard (`pr_staff`), own session cookie | Browsers: HQ, province and station staff |
| Legacy public API | Picksell | `routes/api.php`: `GET /api/products`, `GET /api/search-suggestions`, `PATCH /api/buyer/account` (session) | none / session | No current client found in these repos |
| Legacy rider backend | pickrush/backend | `/api/hubs`, `/api/auth/email-otp/*`, `/api/riders/register` | none | **Unused**: the rider app calls only `/api/rider/*` |

**Shared data:** both buyer APIs read and write the same MySQL tables and the same
`personal_access_tokens` table. The live check confirmed that a token from either API's `/login`
works on the other.

## 2. Buyer API: endpoints (identical lists in both codebases)

`{base}` is `/api` (picksell-buyer) or `/api/mobile` (Picksell). Every route, method, middleware
and throttle matches. Only the throttle key prefixes differ (`register-code` versus
`buyer-api-register-code`), so each server keeps separate limits.

| Method | Path | Auth | Purpose | Live check |
|---|---|---|---|---|
| POST | /register/email-code, /register/email-code/verify, /register/check-contact, /register | none (throttled) | Sign-up: email code first, then details plus ID; the account is pending until an admin approves | static only |
| POST | /login | none | Bearer token | ✅ both |
| POST | /password/forgot, /password/reset | none | Reset by emailed code | static only |
| GET | /home, /categories, /products, /products/{id}, /products/{id}/reviews, /sellers/{id}, /payment-methods, /legal/{terms\|privacy}, /search-suggestions | optional | Catalog | ✅ same data (see §4) |
| GET, PATCH | /buyer/profile; PATCH /buyer/password; POST /buyer/logout | buyer | Account | static only |
| GET, POST, DELETE | /buyer/wishlist[/{product}], /buyer/recently-viewed | buyer | Shared lists | static only |
| GET, POST, PATCH, DELETE | /buyer/cart, /buyer/cart/count, /buyer/cart/{item} | buyer | Cart (one line per product and option) | ✅ add, ownership |
| POST | /buyer/checkout/quote, /buyer/checkout | buyer | COD checkout: one order per line, status `placed` | ✅ order created, stock decremented |
| GET | /buyer/orders[?tab], /buyer/orders/options, /buyer/orders/{id} | buyer, own orders | History, tabs, detail with timeline and Pickrush tracking | ✅ every lifecycle step, both APIs |
| POST | /buyer/orders/{id}/cancel | buyer | Only while placed/confirmed/preparing | ✅ refused (409) after dispatch |
| POST | /buyer/orders/{id}/rate | buyer | Rating, plus a product review once completed | ✅ |
| POST | /buyer/orders/{id}/report, /return (multipart) | buyer | Complaint; return request | static only |
| POST, GET | /buyer/orders/{id}/reorder, /buyer/reorder, /buyer/support/tickets | buyer | | static only |
| GET, POST | /buyer/notifications, /buyer/notifications/read-all | buyer | The website's database notifications | ✅ |
| GET, GET, POST | /chat/contacts, /chat/messages/{userId}, /chat/send | buyer | Chat with sellers and support | ✅ only the buyer's own thread is returned |
| GET | /ping | none | Health | ✅ both |

**Called by the app but served by neither:** `GET /shipping-options`
(`CatalogService.shippingOptions()`). It returns 404 on both servers, but nothing in the app
calls that method, so it's dead code with no user effect.

## 3. Rider API (Picksell `routes/pickrush-api.php`) against the rider app

| Rider app call | Server route | Status |
|---|---|---|
| POST /api/rider/email-code/send, /verify; POST /login; GET /stations; POST /apply | ✅ | login verified live |
| GET /me; POST /logout; POST /application | ✅ | |
| GET /dashboard, /pulse, /options, /notifications; POST /notifications/read; PATCH /shift | ✅ | dashboard, options and notifications verified live with the app's own Dart services |
| GET /batches, /batches/{id}; POST accept, decline, pickups, stops/arrive, hub/arrive, reports, load, start, deliveries/{a}/deliver, deliveries/{a}/fail | ✅ | accept, load, start, arrive and deliver verified live, including retries |
| **GET /api/rider/earnings** | ❌ **not on `feature/buyer-app-api`** (only on `production`, `b36b37d`) | live: 404 "route could not be found"; the Earnings tab fails |
| **POST /api/rider/password** (change) | ❌ only on `production` | the change-password screen fails |
| **POST /api/rider/password/forgot, /password/reset** | ❌ only on `production` | the forgot-password screen fails |

## 4. Where the two buyer APIs differ

Checked by `scripts/check-website-drift.php` (picksell-buyer) and by comparing live responses.

| Area | picksell-buyer `/api` | Picksell `/api/mobile` | Effect | Owner of the fix |
|---|---|---|---|---|
| Order rules (`OrderLifecycleService`, `OrderCancellationService`, `OrderPlacement`, `CartQuote`, status history) | identical | identical | none | keep identical (the script checks this) |
| Cart badge count (`/buyer/cart/count`, profile `cart_count`, reorder `cart_count`) | **sum of quantities** | **number of lines**, as the website shows | The badge shows a different number depending on the server | business decision: pick one |
| Image URLs | `PICKSELL_PUBLIC_STORAGE_URL` (`https://pick-sell.shop/storage/…`) | `APP_URL/storage/…` | Same paths, different host. Locally, the buyer API points images at the public site. | configuration |
| Parcel tracking label | `ucfirst(str_replace('_',' ', status))`, e.g. "In transit to province" | enum `label()`, e.g. "In transit to province hub" | Slightly different wording for 3 line-haul statuses | align with the enum label |
| Chat contact name | admin → "PickSell Support", otherwise the business name | seller → business name, otherwise "PickSell Support" | Same result for today's contacts (sellers and admin) | keep identical |
| Admin alert on `delivery_failed` (Order hook) | no dedupe `subject` | `subject: order:{id}` | none: only Pickrush sets `delivery_failed` | keep identical |
| Throttle counters | own prefixes | `buyer-api-` prefixes | Limits are per server | none |

Live comparison of public responses: `products`, `products/46`, `home` and `products?page=2`
differ **only** in image hosts. `categories`, `reviews`, `payment-methods`, `legal/terms` and
`search-suggestions` are byte-identical. Order detail, status and tab were identical on both APIs
at every lifecycle step.

## 5. Recommended ownership (needs your decision; nothing has been removed or merged)

**Recommendation:** make **Picksell `/api/mobile`** the single buyer API and retire the separate
picksell-buyer server once the app is pointed at it. Reasons:

- It lives next to the code it depends on (the `Order` model, the Pickrush bridge, the lifecycle). picksell-buyer carries hand-copied versions, and the Phase 2 defect had to be fixed in both copies.
- It already matches the website's cart count and tracking labels.
- One deployment and one `.env` instead of two that must agree (DB, commission rate, mail, storage).

**Until you decide:**
1. Keep both. Run `php scripts/check-website-drift.php <Picksell path>` before every release; it exits 1 when an order rule differs.
2. Build the app against **one** of them per environment and write that down in each environment's notes.
3. Commit Picksell's `/api/mobile` work. It's currently uncommitted on `feature/buyer-app-api`.
