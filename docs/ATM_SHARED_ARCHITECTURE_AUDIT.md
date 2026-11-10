# SafarSetu + ATM Shared Architecture Audit

**Date:** 2026-10-26  
**Project root:** `C:\Users\PC\OneDrive\Desktop\safersetu`  
**Scope:** Read-only inspection of the existing applications, backend, API, persistence model, migrations, tests, and relevant audit reports. This audit did not run tests, start services, modify configuration, execute migrations, or access database contents. The only file created is this report.

## Executive result

The repository already has the intended **two Flutter app folders plus one backend**:

1. SafarSetu passenger app: project root (`lib/`, `test/`, `web/`, root `pubspec.yaml`).
2. ATM passenger kiosk: initialized, separate Flutter Web app in `ATM/`.
3. Shared Spring Boot API: `backend/`, configured for one PostgreSQL datasource.

Both Flutter apps use the same default API base URL, `http://localhost:8080/api`, with a compile-time override. The ATM calls existing stops and bus-search endpoints and posts quantity bookings to `POST /api/atm/bookings`. The backend stores bookings as `PassengerBooking` entities and includes confirmed reservations in **booking-time capacity checks**.

The important missing link is read-side occupancy: `BusService` calculates occupancy from `TicketRepository` rows only; it does not read `PassengerBookingRepository`. Therefore an ATM booking is persisted and affects later booking capacity checks, but SafarSetu's current occupancy response does not include that booking or expose remaining passenger capacity including reservations. The current receipt returns a booking reference/booking ID, not a ticket ID. No physical seat numbers or seat maps are in scope or implemented.

PostgreSQL was not confirmed installed and is not reachable on port 5432. Backend port 8080 is not listening. The required DB environment variables are absent. SQL migration files exist, but no migration runner is configured and none were executed. Database-backed behavior remains unverified.

## Current project structure

```text
safersetu/
  lib/                                  Existing SafarSetu Flutter application
    main.dart                           SafarSetuApp entry point
    data/                               Mock/API repositories and API clients
    models/                             Passenger app models
    screens/                            Home, search, trip, details, ETM simulation, etc.
    widgets/                            Existing app widgets
  test/                                 Existing passenger app tests
  web/                                  Existing SafarSetu Flutter Web runner
  pubspec.yaml                          Root Flutter package `safarsetu`
  backend/                              One Spring Boot API / PostgreSQL datasource
    src/main/java/in/safarsetu/backend/
    src/main/resources/application*.yml
    src/test/java/in/safarsetu/backend/
    db/migration/V1__...sql ... V6__...sql
    pom.xml
  ATM/                                  Separate initialized Flutter Web app
    lib/main.dart                       AtmApp entry point
    lib/src/atm_app.dart                Kiosk UI
    lib/src/atm_api.dart                Backend HTTP client and booking contract
    test/                               ATM widget and API tests
    web/                                ATM Flutter Web runner
    pubspec.yaml                        Separate package `safarsetu_atm`
    PROJECT_PLAN.md                     Preserved plan; contains stale pre-initialization status
  passenger_kiosk_app/
    PROJECT_PLAN.md                     Preserved planning document; no app source found
  ETM/                                  Microsoft Cloud Files directory reparse point
  docs/                                 ETM, integration, readiness, and project docs
```

`ATM/` is not plan-only: it contains `lib/main.dart`, `lib/src/atm_app.dart`, `lib/src/atm_api.dart`, `pubspec.yaml`, `web/`, and tests. `ATM/PROJECT_PLAN.md` still says the app had not yet been generated; that statement is stale relative to the actual files. `passenger_kiosk_app/` remains separate and contains its plan only. No folder was moved, removed, or replaced.

## Git and existing user work

`git status --short --branch` and `git rev-parse --show-toplevel` both returned `fatal: not a git repository`. There is no root `.git` metadata visible at the specified project root, so I could not determine a branch, status, diff, or which pre-existing local edits belong to the user. No source file was modified during this audit.

## Application entry points and shared backend configuration

| Application | Entry point / configuration | Backend base URL |
|---|---|---|
| SafarSetu | `lib/main.dart` calls `runApp(const SafarSetuApp())`; `pubspec.yaml` package is `safarsetu` | `lib/data/api_client.dart` reads `SAFARSETU_API_BASE_URL`, default `http://localhost:8080/api`. API mode is selected by `SAFARSETU_DATA_SOURCE=api`; mock mode remains the default. |
| ATM | `ATM/lib/main.dart` calls `runApp(AtmApp(api: AtmApi()))`; `ATM/pubspec.yaml` package is `safarsetu_atm` | `ATM/lib/src/atm_api.dart` reads the same `SAFARSETU_API_BASE_URL`, with the same default. There is no local/mock booking fallback. |
| Backend | `backend/src/main/java/in/safarsetu/backend/SafarSetuBackendApplication.java`; Spring Boot Maven project in `backend/pom.xml` | `backend/src/main/resources/application.yml` defines one datasource via `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`; server defaults to port 8080. |

Both apps can call the same API process and therefore the same backend-managed database. They do not contain embedded or separate backends/databases. Browser deployment still needs the configured backend origin and CORS to match the client origin.

## Existing backend entities and endpoints

### Existing data model

- `entity/Bus.java` references a `Route`, has seating/total passenger capacity, active state, and data origin.
- `entity/Route.java`, `entity/RouteStop.java`, and `entity/RouteStopId.java` represent routes with ordered stops.
- `entity/Stop.java` represents canonical internal stops.
- `entity/Ticket.java` stores ticket ID, bus, boarding/destination stops, passenger count, timestamp, string `tripId`, idempotency key, data origin, and optional booking relation.
- `entity/PassengerBooking.java` stores a quantity reservation, booking reference/idempotency key, trip string, bus, ordered segment, count, status, and creation timestamp.
- `entity/SimulatedTripArrival.java` stores simulated arrivals and derived expected alighting.
- `entity/OccupancySnapshot.java` exists, but the live occupancy service calculates from ticket journeys rather than treating snapshots as authoritative.
- `service/OccupancyCalculator.java` applies `boardingOrder <= queryOrder && destinationOrder > queryOrder` and sums passengers for a route segment.

There is no canonical relational `Trip`/`ServiceRun` entity in active application code. `tripId` is a string supplied in requests; the kiosk generates a synthetic deterministic demo trip ID.

### Relevant HTTP endpoints

| Endpoint | Defined in | Current role |
|---|---|---|
| `GET /api/health` | `controller/HealthController.java` | Process liveness only; it does not prove database readiness. |
| `GET /api/stops?page=0&size=100` | `controller/RouteController.java` | Paginated stop list for ATM selection. |
| `GET /api/routes` and `GET /api/routes/{routeId}` | `controller/RouteController.java` | Route listing/details. |
| `GET /api/routes/{routeId}/stops` | `controller/RouteController.java` | Ordered stops for an internal route. |
| `GET /api/buses` | `controller/BusController.java` | Paginated buses. ATM filters active `SIMULATED` buses client-side. |
| `GET /api/buses/search?fromStopId=…&toStopId=…` | `controller/BusController.java` | Finds buses serving the ordered internal stop pair. |
| `GET /api/buses/{busId}/occupancy?stopId=…&tripId=…` | `controller/BusController.java` | Returns ticket-derived occupancy for a stop/trip. **Confirmed bookings are not included in this response today.** |
| `POST /api/atm/bookings` | `controller/PassengerBookingController.java` | Creates a simulation booking and returns `bookingReference`, `bookingId`, and journey/status data. It does not return a ticket ID. |
| `POST /api/etm/tickets` | `controller/BusController.java` | Simulation-only ticket event ingestion; an optional booking reference links a matching kiosk booking to a simulated ticket event. |
| `POST /api/etm/simulated/arrivals` | `controller/SimulatedArrivalController.java` | Simulation-only route arrival with ticket-derived expected alighting. |

## Shared booking-to-occupancy readiness

1. **Can both apps call the same backend?** Yes by source configuration. Both default to `http://localhost:8080/api`; each can use `SAFARSETU_API_BASE_URL` to target the same deployed backend. Live connectivity was not established.
2. **Bus and route discovery?** Yes. ATM uses `GET /api/stops`, `GET /api/buses/search`, and `GET /api/routes/{routeId}/stops`.
3. **Passenger booking API?** Yes. `POST /api/atm/bookings` exists in `PassengerBookingController`.
4. **Can the backend persist a booking?** Source says yes: `PassengerBookingService` saves a `PassengerBooking` using `PassengerBookingRepository`/JPA. Database schema availability has not been verified.
5. **Capacity on booking?** Yes, at service level. `PassengerBookingService` combines same-trip ticket journeys with confirmed reservation journeys and checks the segment load using `OccupancyCalculator`; it obtains a pessimistic bus lock. Ticket ingestion also includes confirmed bookings in capacity checks. Actual PostgreSQL locking is unverified.
6. **Capacity across route segments?** The interval calculation counts a passenger from boarding through the stop immediately before destination. The booking check evaluates the journey along the route, allowing distinct segment capacities. This is quantity-based; it does not allocate seats.
7. **Can SafarSetu fetch after a booking?** It can re-request bus search/details/occupancy from the shared backend. Its API repository requests occupancy for searched buses and on detail loading. But the occupancy service reads only ticket rows; a new reservation alone will not change the returned onboard occupancy, crowd category, or seat estimate. There is no push/subscription refresh between apps.
8. **Does the kiosk issue a ticket ID?** No. It returns a booking reference and booking ID. A simulated ETM ticket ID is created only if a separate ETM ticket event is submitted later.

### Minimum shared data-flow changes

- Decide and expose two distinct quantities: **ticket/event-derived onboard estimate** and **confirmed booked/reserved passengers**. Do not label reservations as physically onboard.
- Extend the occupancy/read API with segment-scoped reserved quantity and remaining total passenger capacity (and define separately whether provisional seat availability includes bookings). Include confirmed `PassengerBooking` rows for the requested bus/trip/stop interval.
- Update `OccupancyDto`, `BusService`, occupancy tests, and SafarSetu's `OccupancyData`/API adapter/UI to show these values and refresh/re-query after the user changes journey/search context. Keep occupancy and reservation semantics explicit.
- Decide whether the kiosk should continue to issue a booking reference or should issue a separately defined ticket ID. Avoid calling a reservation a ticket/boarding event without an explicit product lifecycle.

## Database, migrations, and runtime state

### Configuration and migration readiness

- `backend/src/main/resources/application.yml` defines a single datasource from `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`, and defaults Hibernate schema mode to `validate`.
- `application-dev.yml` changes the dev default to `DDL_AUTO:update` and enables insert-only demo seeding by default (`SEED_DEMO_DATA=true`). Starting with these defaults may update the schema and insert fixture rows. The audit did not start the backend.
- `application-prod.yml` uses `validate` and disables seeding.
- `backend/pom.xml` contains Spring Web MVC, Data JPA, Validation, PostgreSQL JDBC, and test dependencies. No Flyway or Liquibase dependency or migration runner was found.
- `backend/db/migration/V1__ticket_trip_context.sql` adds/backfills a ticket trip string; V2 proposes simulated arrival storage; V3 proposes relational service runs; V4 proposes provider/device/identifier mappings; V5 proposes a provider event ledger; V6 proposes passenger bookings and `tickets.booking_id`.
- V1–V6 are draft SQL files, not an active automated migration sequence. None was executed in this audit. V3–V5 are largely proposals without matching runtime entities/repos.
- **Schema discrepancy:** `V2__simulated_trip_arrivals.sql` has unique `(bus_id, trip_id, stop_order)`, while `SimulatedTripArrival.java` declares uniqueness only on `(trip_id, stop_order)`. Reconcile before using Hibernate schema generation or a migration.

### Current machine evidence

- PostgreSQL port **5432 does not accept a localhost connection** at audit time.
- `psql` and `pg_ctl` were not found in PATH. A Windows PostgreSQL service query was denied by Service Control Manager permissions, so installation/service presence could not be established.
- `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` were all absent from the current process environment; no values were printed.
- Backend port **8080 is not listening**.
- Conclusion: PostgreSQL installation is **unknown**, PostgreSQL is **not reachable**, and backend/database connectivity is **not verified**. Do not treat a successful `/api/health` response by itself as DB readiness.

## Tests and known tooling constraints

Commands documented in the project:

```powershell
# SafarSetu, from project root
flutter pub get
flutter analyze
flutter test --no-test-assets

# ATM, from ATM/
flutter pub get
flutter analyze
flutter test

# Backend, from backend/
mvn test
```

The reports record previous successful mocked/unit checks (root Flutter: 34 tests; ATM: 4 tests; backend: 69 tests). Those results are historical, not rerun for this audit, and do not establish PostgreSQL or cross-app end-to-end behavior. The ETM implementation report contains earlier test counts; the latest product readiness report records the 69-test backend run.

Known environment issues documented or observed:

- The installed Flutter wrapper has previously stalled silently when it cannot write the SDK cache lock in the restricted execution context. `flutter analyze` stalled for 40 seconds in the latest previous verification attempt; do not assume a Flutter command will finish in this environment.
- Plain root `flutter test` previously could not delete the protected OneDrive `build/unit_test_assets` directory; the project uses `flutter test --no-test-assets` as the workaround.
- Maven tests use Mockito/MockMvc and do not prove database migrations, JPA persistence, rollback, or real row-lock concurrency.
- Root Git status cannot be obtained because `.git` metadata is absent.
- No tests were run as part of this report-only audit.

## Minimum implementation sequence

1. Preserve the current root SafarSetu app and the initialized `ATM/` app; do not create another kiosk folder or backend.
2. Define ticket/reference semantics and reservation-versus-onboard occupancy fields. Keep quantity capacity distinct from seat allocation.
3. Add confirmed bookings to the read-side segment occupancy/capacity API without presenting bookings as observed onboard passengers; update SafarSetu's DTO, adapter, and UI accordingly.
4. Add unit/API tests for multiple bookings, booking + ticket overlap, alighting segment boundaries, trip isolation, and booking updates as observed ticket events arrive. Verify response semantics after an ATM booking.
5. Reconcile V2's entity/SQL uniqueness mismatch; review V1–V6 against the actual intended schema. Choose and configure a migration mechanism only after schema review and backup planning.
6. Establish or identify the existing local PostgreSQL installation/database, obtain connection settings securely, and validate the reviewed schema. Do not initialize a new database or apply migrations without approval.
7. Run backend and both Flutter checks. Start the single backend against the reviewed database and exercise ATM booking followed by SafarSetu refresh in both web clients. Verify actual cross-origin configuration if app origins differ.

## Direct readiness answer

**Ready:** the two separate Flutter application folders, shared API client convention/base URL, common Spring Boot backend, bus/route/stop lookup endpoints, quantity booking endpoint and JPA model, booking-time route-segment capacity checks, and SafarSetu's existing ticket-derived occupancy endpoint.

**Missing or blocked:** occupancy read-side inclusion of reservations; a ticket ID lifecycle for the kiosk; confirmed PostgreSQL installation/connectivity and schema; a migration runner and verified migrations; fresh Flutter/backend/database end-to-end verification; and known Git baseline. The current ATM plan document is stale about initialization state.

**Next implementation step:** update the backend occupancy contract and `BusService` to return separately labeled, segment-scoped **reserved passenger count** and **remaining total passenger capacity** including confirmed bookings, then update SafarSetu's occupancy model/UI and add tests. Do not count reservations as observed onboard passengers or assign physical seat numbers.
