# Putting the buyer app online (api.pick-sell.shop)

The app's server runs **on the same laptop as the website**, next to it, and
is reached through the same Cloudflare Tunnel at `https://api.pick-sell.shop`.
Phones then work from anywhere with internet; nothing is plugged into the
laptop. The laptop must stay on and connected while the app is in use.

Read `shared-database.md` first: this server uses the website's database and
uploaded files.

Commands assume Windows, PHP 8.4 (`C:\php84\php.exe`) and the website at
`C:\projects\PickSell\PickSell`; adjust the paths to that laptop.

## 1. Update the website (adds the shared tables)

```
cd C:\projects\PickSell\PickSell
git pull                      # the branch with the wishlist / recently viewed change
php artisan migrate --force   # creates wishlist_items and recently_viewed_products
npm ci && npm run build       # rebuilds the website's CSS
```

Back up the database before migrating (`mysqldump picksell > backup.sql`).

## 2. Install this project on the same laptop

```
git clone https://github.com/ChristianSorromero/picksell_buyer.git C:\projects\picksell-buyer
cd C:\projects\picksell-buyer
git checkout feature/buyer-mobile-app
php composer.phar install --no-dev --optimize-autoloader
copy .env.production.example .env
php artisan key:generate
```

Edit `.env`:

| Setting | Value |
|---|---|
| `APP_URL` | `https://api.pick-sell.shop` |
| `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | Same as the website's `.env` |
| `DB_TIMEZONE` | Same as the website's (empty if the website doesn't set it) |
| `PICKSELL_PUBLIC_STORAGE_ROOT` | The website's `storage\app\public`, e.g. `C:\projects\PickSell\PickSell\storage\app\public` |
| `PICKSELL_PUBLIC_STORAGE_URL` | `https://pick-sell.shop/storage` |
| `PLATFORM_COMMISSION_RATE` | Same as the website's (default 10) |
| `MAIL_*` | The website's mail account, so sign-up and reset codes are delivered |

Then:

```
php artisan migrate --force        # only adds the app's login-token table if missing
php artisan picksell:preflight     # must end with "No blockers found"
php artisan config:cache
php artisan route:cache
```

## 3. Run it

Serve this project on a local port the website doesn't use, e.g. **8001**:

- **Same way as the website:** if the website runs under Apache/XAMPP, add
  a virtual host whose document root is `C:\projects\picksell-buyer\public`
  on port 8001.
- **Simplest:** `php artisan serve --host=127.0.0.1 --port=8001`, kept
  running (it handles one request at a time; fine for a small group of
  testers).

Check it: open `http://127.0.0.1:8001/api/ping` on the laptop → `{"ok":true}`.

## 4. Add api.pick-sell.shop to the Cloudflare Tunnel

**Tunnel managed in the Cloudflare dashboard** (installed with a token):
Zero Trust → Networks → Tunnels → the website's tunnel → Public Hostname →
Add: subdomain `api`, domain `pick-sell.shop`, service `HTTP`,
URL `localhost:8001`. Save.

**Tunnel managed with a config file** (`%USERPROFILE%\.cloudflared\config.yml`):
add the rule above the catch-all, then route DNS and restart:

```yaml
ingress:
  - hostname: api.pick-sell.shop
    service: http://localhost:8001
  # … the existing pick-sell.shop / logistics.pick-sell.shop rules …
  - service: http_status:404
```

```
cloudflared tunnel route dns <tunnel-name> api.pick-sell.shop
```

Check it from any phone or computer: `https://api.pick-sell.shop/api/ping`.

## 5. Build the app for phones

```
flutter build apk --release --dart-define=API_BASE_URL=https://api.pick-sell.shop/api
```

Install `build\app\outputs\flutter-apk\app-release.apk` on the phones. Release
builds only talk to https addresses, so they need the tunnel address above.

## Updating later

1. Website changes first: pull, `php artisan migrate --force` in PickSell.
2. This project: pull, `composer install --no-dev`, `php artisan migrate --force`,
   `php artisan config:cache`, restart the server from step 3.
3. If the website's migrations changed, refresh the test schema on a
   development PC (`php scripts/sync-website-schema.php <website path>`).
