# How the buyer app shares the PickSell website's data

The buyer mobile app's server (this project) has **no database of its own**.
It reads and writes the PickSell website's MySQL database (`picksell`), and
uses the website's uploaded files. An order placed in the app is a normal
website order: the seller, admins, Pickrush staff and riders see it at once,
and their updates reach the app.

```
Phone app ──https──▶ api.pick-sell.shop ─┐
                     (this project)       ├──▶ MySQL `picksell` + website storage
Browser ───https──▶ pick-sell.shop ──────┘
                     (PickSell website)
```

## Rules

1. **The website owns the database layout.** Tables and columns are created
   only by the website's migrations (`php artisan migrate` in the PickSell
   project). This project's `php artisan migrate` adds one table, the app's
   login tokens (`personal_access_tokens`), and records it in its own
   `mobile_api_migrations` table. Never add a migration here that creates or
   changes a website table.
2. **Business rules match the website.** When the website changes a buyer
   rule, change it here too (see the table below).
3. **Same settings.** `DB_*`, `DB_TIMEZONE`, `PLATFORM_COMMISSION_RATE` and the
   mail account must match the website's `.env`. File uploads go to the
   website's `storage/app/public` (`PICKSELL_PUBLIC_STORAGE_ROOT`).
4. **No demo data.** The seeder is empty on purpose; this is the live database.

## Buyer rules and where they come from

| App feature | Website rule it follows | Code here |
|---|---|---|
| Sign-up | Email code first, then the details with a valid ID and address; the account stays **pending** until an admin approves it on the Registrations page (`AuthController::register`) | `MobileAuthController` |
| Address codes | PSGC codes resolved from the address names (`AddressResolver`), used by Pickrush routing | `User::booted`, `Services/Geo` |
| Catalog | Active products in stock from approved sellers (`Product::purchasable`) | `CatalogController::listable` |
| Cart | One line per product and variation; adding again raises the quantity | `CartController` |
| Price | Product price minus its discount; a voucher is the product's own code (case-sensitive); no delivery or service fee | `OrderPlacement::unitPrice`, `CartQuote` |
| Checkout | One order per cart line, `ORD-` number, status `placed`, commission from `PLATFORM_COMMISSION_RATE`, stock checked per product under a lock, seller notified (`NewSellerOrder`) | `OrderPlacement` |
| Payment and delivery | Cash on Delivery to the buyer's profile address | `CheckoutController` |
| Order steps | The website's lifecycle in `orders.status`, history in `order_status_histories` | `Order`, `Services/Orders` |
| Cancel | Buyer may cancel while Placed, Confirmed or Preparing; stock goes back (`OrderCancellationService`) | `OrderController::cancel` |
| Rating | The order rating; once completed, also the product review (`product_reviews`) | `OrderController::rate` |
| Returns | Delivered or completed, once per order, the website's reasons, up to 5 photos/videos; the seller reviews first, then admins | `OrderController::requestReturn` |
| Report a problem | A complaint on the website's Complaints page | `OrderController::report` |
| Tracking | Pickrush parcel scans (`pr_parcels`, `pr_parcel_events`) | `Models/Pickrush`, `BuyerPresenter::tracking` |
| Notifications | The buyer's website notifications (order updates, messages); read on one side, read on both | `NotificationController` |
| Chat | Approved sellers the buyer messaged or ordered from; PickSell support once written to | `ChatController` |
| Wishlist, Recently viewed | Shared tables `wishlist_items`, `recently_viewed_products` (website migrations) | `WishlistController`, `RecentlyViewed` |

## Tests

The tests run on an exact copy of the website's tables in
`database/schema/sqlite-schema.sql`. When the website's migrations change,
refresh it:

```
php scripts/sync-website-schema.php C:\projects\PickSell\PickSell
php artisan test
```

## Known website-side gaps (not changed here)

- ID uploads and return/complaint evidence are on the website's **public**
  disk, so anyone with a file's URL can open it. The app stores files in the
  same place so admins can see them; moving them to private storage is a
  website change.
- The website keeps a chosen variation on the cart line only; orders don't
  record it, and choosing options in two groups keeps only the last one. The
  app therefore allows one option per cart line.
- App and website password resets share `password_reset_tokens`; the most
  recent request for an email wins.
- Push notifications are not set up; the app shows new notifications when it
  refreshes.
