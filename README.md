# PickSell buyer app

The PickSell buyer mobile app (Flutter, `lib/`).

The app has no server of its own. It depends on the **PickSell website**: every
call goes to the website's buyer API, `/api/mobile` (`routes/buyer-api.php` in
the Picksell repo). An order placed in the app is an ordinary website order, and
buyer rules (sign-up approval, pricing, vouchers, cancelling, returns) are the
website's. The app only uses endpoints the website already serves; a feature
the website's buyer API doesn't offer stays out of the app.

## Develop

```
flutter analyze && flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/mobile        # emulator
flutter build apk --dart-define=API_BASE_URL=https://pick-sell.shop/api/mobile
```

For local runs, start the Picksell website (`php artisan serve` in that repo)
against a test database, never the live one. Release builds require an
`https://` API URL.

The app's former Laravel API was retired on 2026-11-07; it lives in git history
(before that commit) if it is ever needed for reference.
