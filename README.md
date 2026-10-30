# PickSell buyer app

The PickSell buyer mobile app (Flutter, `lib/`) and its API server
(Laravel, `app/`, `routes/api.php`).

The server shares the **PickSell website's database and uploaded files**: an
order placed in the app is an ordinary website order, and website, seller,
admin and Pickrush updates appear in the app. Buyer rules (sign-up approval,
pricing, cancelling, returns) follow the website.

- How the sharing works and which website rule each feature follows:
  [documentation/shared-database.md](documentation/shared-database.md)
- Putting it online at `api.pick-sell.shop`:
  [documentation/deployment.md](documentation/deployment.md)

## Develop

```
C:\php84\php.exe artisan test        # API tests (on a copy of the website's tables)
flutter analyze && flutter test      # app checks
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Copy `.env.example` to `.env` and point the `DB_*` settings at the website's
database. Never run seeders or add migrations for website tables here.
