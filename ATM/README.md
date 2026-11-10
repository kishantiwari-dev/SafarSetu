# SafarSetu Passenger ATM (simulation)

This is the separate Flutter Web passenger kiosk in `ATM/`. It uses the existing Spring Boot API and PostgreSQL; it does not include a second backend or a local/mock booking fallback. `PROJECT_PLAN.md` remains preserved.

## Run locally

Prerequisites: Flutter 3.47.2/Dart 3.13.2 or a compatible Flutter SDK, Microsoft Edge, and the existing SafarSetu backend with the reviewed booking schema available. The kiosk API base defaults to `http://localhost:8080/api` and can be overridden at build/run time.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge --dart-define=SAFARSETU_API_BASE_URL=http://localhost:8080/api
```

If the backend is unavailable, the kiosk shows a connection error and retry action. It does not switch to mock data.

## What the simulation supports

- Load backend stop IDs/names and search active simulated buses serving the selected ordered stop pair.
- Choose a quantity from 1 to 20; there are no seats, seat numbers, or seat maps.
- Submit an idempotent request to `POST /api/atm/bookings` and display the server reference and simulation status.
- Let the backend count overlapping ETM ticket journeys and confirmed bookings against total passenger capacity for the same synthetic run and route segment.

The backend currently has no authoritative dated runs, schedule, fare, payment, cancellation, or reservation expiry. The demo run ID is synthetic (`SIM-TRIP-{busId}-DEMO-01`). A booking receipt is not proof of payment, physical boarding, or a verified ticket. Do not expose the unauthenticated simulation API to public networks.

See [`../README.md`](../README.md) for system startup, database safety, backend configuration, and test commands. See [`../docs/FINAL_PRODUCT_READINESS_REPORT.md`](../docs/FINAL_PRODUCT_READINESS_REPORT.md) for verified status and remaining release blockers.
