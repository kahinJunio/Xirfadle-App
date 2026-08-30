# Xirfadle Mobile App

Flutter client for **Xirfadle**, a local service-matching platform. One codebase
serves two modes — **Customer** and **Skilled Person (Provider)** — routed by the
`role` claim in the JWT issued by the ASP.NET Core Web API.

Admins broker every job off-platform: a customer files a request, an admin calls
to confirm details and price, then dispatches it to a provider who accepts or
rejects it in-app.

## Stack

| Concern | Choice |
| --- | --- |
| State management | `flutter_riverpod` (feature-first, `StateNotifier` + `FutureProvider`) |
| Routing | `go_router` with a role-based navigation guard |
| Networking | `dio` with JWT injection and single-flight token refresh |
| Token storage | `flutter_secure_storage` (Keystore / Keychain) |
| Preferences | `shared_preferences` |
| Location & maps | `geolocator` + `flutter_map` (OpenStreetMap — no API key needed) |

## Getting started

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-host/api/v1
```

The base URL defaults to `https://api.xirfadle.com/api/v1`
(`lib/app/config/api_config.dart`). Override it per environment with
`--dart-define`; no source edit required.

Common targets:

```bash
# Android emulator against a local backend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1

# iOS simulator against a local backend
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api/v1
```

Verify a change:

```bash
flutter analyze   # must report no issues
flutter test      # 56 tests
```

## Backend contract

The client is tolerant of camelCase and PascalCase keys, and unwraps
`{ "data": [...] }` envelopes, so most ASP.NET Core serializer settings work
unchanged.

### Auth

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/login` | `{ phoneNumber, password }` → `{ accessToken, refreshToken? }` |
| POST | `/auth/register` | `{ fullName, phoneNumber, password, role, categoryId? }` |
| POST | `/auth/refresh` | `{ refreshToken }` → `{ accessToken, refreshToken? }` |
| GET | `/auth/me` | Optional profile top-up; failures are non-fatal |

The access token must carry a `role` claim (short name or the Microsoft claim
URI). `Customer`, `Provider`, `Admin` and synonyms such as `ServiceProvider` are
recognised. An account holding both roles gets a mode switcher in the profile.

### Customer

| Method | Path |
| --- | --- |
| GET | `/customer/categories` |
| GET | `/customer/providers?categoryId=&search=&latitude=&longitude=` |
| GET | `/customer/providers/{id}` |
| GET | `/customer/providers/{id}/reviews` (optional — absence is tolerated) |
| POST | `/customer/requests` |
| GET | `/customer/requests`, `/customer/requests/{id}` |
| PATCH | `/customer/requests/{id}/cancel` |
| POST | `/customer/reviews` |

### Provider

| Method | Path |
| --- | --- |
| GET | `/provider/requests`, `/provider/requests/{id}` |
| PATCH | `/provider/availability` — `{ isAvailable }` |
| PATCH | `/provider/requests/{id}/respond` — `{ status, rejectionReason? }` |
| PATCH | `/provider/requests/{id}/start` |
| PATCH | `/provider/requests/{id}/complete` |

`/start` is not in the original spec; it backs the middle step of the provider
job tracker. If the backend has no such endpoint, drop the **Start work**
button in `active_job_screen.dart` and let *Accepted* go straight to *Completed*.

### Request state machine

`RequestStatus` (`lib/core/models/request_status.dart`) is the single source of
truth for badge text, colour and the actions each screen offers.

| Wire value | Customer sees | Provider sees |
| --- | --- | --- |
| `PendingAdminReview` | Admin Reviewing (amber) | Awaiting Admin |
| `ConfirmedByAdmin` / `Assigned` | Matching Provider (blue) | Awaiting Your Response |
| `AcceptedByProvider` | Provider Assigned & Confirmed (green) | Accepted |
| `RejectedByProvider` | Re-matching Provider (red) | Rejected |
| `InProgress` | Work In Progress (green) | In Progress |
| `Completed` | Completed — Tap to Rate (grey) | Completed |
| `Cancelled` | Cancelled (red) | Cancelled |

Unknown status strings fall back to `PendingAdminReview` rather than crashing.

## Layout

```
lib/
├── app/config/          api_config, app_theme, app_routes, app_router
├── core/
│   ├── models/          request_status, service_request, service_provider,
│   │                    service_category, app_user, user_role, json_utils
│   ├── network/         dio_client, api_interceptors, api_exception, session_gate
│   ├── storage/         secure_storage_service (tokens + preferences)
│   ├── utils/           formatters, validators, location_service
│   └── widgets/         status_badge, rating_stars, async_value_view, app_snackbar
└── features/
    ├── auth/            data · application · presentation
    ├── customer/        data · application · presentation
    ├── provider/        data · application · presentation
    └── shared/          app_shell, profile_screen
```

Each feature keeps `data/` (repository), `application/` (Riverpod controllers
and providers) and `presentation/` (screens and widgets) separate.

## How auth routing works

1. `AuthController` restores any stored token on cold start; the router holds on
   the splash screen while `AuthStatus.unknown`.
2. Claims are decoded into an `AppUser`. `activeRole` picks the dashboard —
   `/customer/home` or `/provider/home`.
3. The `redirect` guard in `app_router.dart` keeps signed-out users in the auth
   flow and keeps each role inside its own section of the app.
4. On a 401 the interceptor refreshes once (single-flight, shared across
   concurrent failures) and retries. If the refresh fails, `SessionGate` notifies
   `AuthController`, which clears the tokens and bounces to login with an
   explanation.

## Permissions

Location is **optional** everywhere. Denying it drops proximity ranking and the
map pin; manual address entry still works.

- Android: `INTERNET`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`
- iOS: `NSLocationWhenInUseUsageDescription`
