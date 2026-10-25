# Notification events

Push notifications are not implemented, and no push provider or credentials
are configured.

What exists today:
- **Buyer app:** reads its notifications from the order timeline
  (`order_events`) when it refreshes.
- **Admins:** in-app notifications in the database `notifications` table
  (the bell in the admin panel).
- **Email:** account and verification messages, password reset codes.

The events below are already recorded in the database, so a push channel
can be added later without changing the business workflows. Each row names
the record a sender would watch.

| Event | Recipient | Recorded in | Push today |
|---|---|---|---|
| Order placed / status changes (preparing, picked up, sorting, rider assigned, out for delivery, delivered, completed, cancelled) | Buyer | `order_events` | No (app polls) |
| Delivery attempt failed / returned to seller | Buyer, seller | `order_events`, `delivery_attempts` | No |
| Return requested, buyer replied, escalated | Admins | `notifications` (admin bell) | In-app only |
| Info requested / seller proposal waiting | Buyer | `return_requests.status`, `audit_logs` | No (shown in app) |
| Case approved for seller | Seller | `audit_logs` | No (seller Returns page) |
| Refund handed over | Buyer | `order_events` (`refunded`) | No |
| Pickup or refund cash assigned | Rider | `return_requests`, `audit_logs` | No (rider dashboard) |
| Payout completed | Seller, rider | `payouts`, `audit_logs` | No (Payouts pages) |
| Email verification / password reset code | Buyer | — | Email |

To add push later:
1. Register device tokens per user (a new table).
2. Choose a provider (e.g. Firebase Cloud Messaging) and store its
   credentials as secrets.
3. Send from model observers or queued jobs on the records above.

Each of these needs approval, because it adds an external service and
credentials.
