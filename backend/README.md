# SafarSetu backend

Spring Boot REST API for deterministic **simulated** Gautam Buddha Nagar bus and ETM data. It does not represent an official bus operator or live public transport. Flutter has an opt-in API mode for journey search and bus details; local mock mode remains its default. `GET /api/health` returns `{"status":"UP"}` when the application is running and does not check PostgreSQL readiness.

## Requirements

- Java 21 and Maven 3.6.3+ (the inspected machine has Adoptium JDK 21.0.8, a Maven 3.9.16 launcher that uses Oracle JDK 24.0.2, and a Java 21 compilation target).
- PostgreSQL 14+ (not verified as installed in the current environment).
- Spring Boot 4.1.1, Spring MVC, Spring Data JPA/Hibernate, Jakarta Validation, PostgreSQL JDBC, JUnit 5/Mockito.

## Local database setup

Create a dedicated local database and role yourself using PostgreSQL administration tools. Do not point this prototype at a production database. Supply the connection settings as environment variables; there are no credential defaults in `application.yml`.

After creating a local PostgreSQL role through your normal administrator workflow, create the empty database once with `createdb --username your-local-role safarsetu` (replace `your-local-role` with your configured role) or run `CREATE DATABASE safarsetu;` in `psql`. Hibernate's local `update` schema initialization creates the tables when the application starts. This command creates a database only; it does not create a role or set a password.

PowerShell example (enter your own local password at the prompt; do not commit it):

```powershell
$env:DB_URL = 'jdbc:postgresql://localhost:5432/safarsetu'
$env:DB_USERNAME = 'your-local-role'
$secureDbPassword = Read-Host 'Local PostgreSQL password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureDbPassword)
try {
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  Remove-Variable secureDbPassword, passwordPointer
}
$env:DDL_AUTO = 'update'
$env:SEED_DEMO_DATA = 'true'
```

`DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` are required. Startup fails with a configuration-specific message when any is missing, and rejects a non-PostgreSQL JDBC URL; the service does not fall back to an in-memory or default database. `.env.example` is a variable template; Spring does not load `.env` files automatically. Copy values into your shell or a local secret manager. Never commit a populated `.env` file. Hikari connection/validation timeouts and pool size are configurable with `DB_CONNECTION_TIMEOUT_MS`, `DB_VALIDATION_TIMEOUT_MS`, and `DB_POOL_MAX_SIZE`.

Location freshness defaults to 15 minutes and occupancy event freshness to 30 minutes (`LOCATION_STALE_AFTER`, `OCCUPANCY_STALE_AFTER`, ISO-8601 durations). Crowding bands use total passenger capacity: <40% LOW, 40–69% MODERATE, 70–89% HIGH, and >=90% NEARLY_FULL. Configure band boundaries with `CROWDING_MODERATE_PERCENT`, `CROWDING_HIGH_PERCENT`, and `CROWDING_NEARLY_FULL_PERCENT`. Invalid or non-increasing bands stop application startup. Simulated records stay marked `SIMULATED` at every age; occupancy's `dataUpdatedAt` is the latest actual selected-trip ticket-event timestamp.

## Run, test, and build

From `backend/`:

```powershell
mvn spring-boot:run
mvn test
mvn package
```

The first Maven run needs the declared dependencies available in the local Maven cache or Maven Central. The default profile is `dev`; it uses Hibernate `update` and the deterministic insert-only seeder. Set `SEED_DEMO_DATA=false` to disable local seed insertion. `DDL_AUTO` can override the development schema mode. `update` is non-dropping but is not a production migration strategy; use reviewed migrations before deploying.

## Production profile and deployment boundary

Set `SPRING_PROFILES_ACTIVE=prod` explicitly. The production profile disables demo seeding, forces Hibernate `validate`, and configures PostgreSQL JDBC `sslmode=verify-full`; provide a trusted database CA certificate according to the PostgreSQL JDBC driver and deployment environment. Production still requires `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`. Do not put credentials in source control or in the Flutter app. Keep database network access private and use a least-privilege database role.

Production CORS is disabled unless `CORS_ALLOWED_ORIGINS` is configured with comma-separated exact HTTP(S) origins, with no path or wildcard, for example `https://passengers.example.com`. Dev CORS patterns are limited to localhost and 127.0.0.1. Do not deploy with the `dev` profile or broaden CORS to `*`.

This API has **no authentication or authorization**. Every endpoint, including `POST /api/etm/tickets`, is unauthenticated. Do not expose it to the public internet or use it for real passenger or operator data until identity, authorization, abuse controls, and protected ticket ingestion are implemented and reviewed. The app's login screen is also a local prototype, not an account system. Configure HTTPS at the deployment edge and restrict inbound API access to trusted clients while authentication remains absent.

The base profile uses Hibernate `validate`; the dev profile explicitly opts into `update`. The production profile cannot be switched to `update` through `DDL_AUTO`. Adopt reviewed Flyway/Liquibase migrations and verify them against a backup before any production schema change. No database creation, reset, or destructive migration is performed by startup.

## Example requests

```text
GET http://localhost:8080/api/health
GET http://localhost:8080/api/stops?page=0&size=20
GET http://localhost:8080/api/routes/SIM-GN-001/stops
GET http://localhost:8080/api/buses/search?fromStopId=KP_II&toStopId=PARI_CHOWK&page=0&size=20
GET http://localhost:8080/api/buses/BUS-SIM-001/occupancy?stopId=KP_II
GET http://localhost:8080/api/buses/BUS-SIM-001/location
```

The API contract documents response DTOs, errors, and simulated data limitations. Bus locations and tickets in the supplied dataset are marked `SIMULATED`; no verified live transit provider is connected.

## Flutter client

See [`../docs/FLUTTER_BACKEND_INTEGRATION.md`](../docs/FLUTTER_BACKEND_INTEGRATION.md) for mock/API source selection, base URLs for host/emulator/device, Flutter Web CORS, and frontend commands. The workspace now includes a Flutter Web runner; Android/iOS runner directories and their platform-specific network permissions have not been configured or tested here.

## Seed, reseed, and reset

The dev seeder inserts stable identifiers and skips existing rows. Restarting or rerunning it does not clear tables or duplicate seeded rows. Seed records are tagged `SIMULATED`; all supplied coordinates are `APPROXIMATE`.

No reset runs automatically. To reset a disposable development database, first verify the configured `DB_URL` is the intended local database, stop the backend, make any needed backup, and manually drop/recreate that development database with PostgreSQL administration tools. Restart with `SEED_DEMO_DATA=true`. Do not use this procedure on any database containing user or production data. Editing seed fixtures does not overwrite existing rows with those IDs; an explicit manual development reset is needed to apply fixture changes.

## Occupancy and seat semantics

For route order `q`, a ticket with boarding order `b`, destination order `d`, and passenger count `p` contributes `p` exactly when `b <= q && d > q`. The result is occupancy immediately after all events at the queried stop; passengers exit at their destination stop. `route_stops.stop_order` is the ordering source. Its values must be complete, unique, and contiguous from zero. Ticket timestamps do not affect this route-position calculation.

The existing `OccupancyCalculator` validates ticket IDs, positive passenger counts, route bounds, and boarding-before-destination order. `BusService` validates the bus route, queried stop, and ticket relationships and returns the occupancy DTO. Duplicate ticket IDs or inconsistent route/ticket data produce HTTP 409. `TicketService` retains unique ticket/idempotency checks and route validation. Ticket ingestion takes a pessimistic write lock on the bus row while it validates the aggregate ticket count and inserts, serializing capacity checks for concurrent submissions to the same bus. Unique database constraints remain the final duplicate guard. This lock behavior still requires PostgreSQL integration testing.

Tickets now carry a `tripId`, and both occupancy calculation and ticket-ingestion capacity validation are scoped to one bus trip. Occupancy can infer the trip only when there is exactly one assigned trip; when several trips exist, callers must pass `tripId` to `GET /api/buses/{busId}/occupancy`. Legacy rows without trip identity are excluded and yield an explicit unknown result when they prevent safe inference. Ticket timestamps are validated on ingestion but do not change route-position occupancy. This is still simulated data, not a live ETM feed.

Total passengers and seated passengers are different quantities. No seated count is recorded. When ticket data exists, `provisionalAvailableSeats` is `seatingCapacity - onboardPassengers`, explicitly under a one-passenger-per-seat assumption. A negative value is returned with `OCCUPANCY_EXCEEDS_SEATING_CAPACITY`; it is never clamped. Occupancy above known `totalPassengerCapacity` returns HTTP 409. Missing ticket data returns an unknown onboard count with `NO_TICKET_DATA`, not a measured zero. Without a location to select a stop, the no-query endpoint returns `NO_LOCATION` and unknown occupancy. Stored `OccupancySnapshot` rows are retained as seed examples and are not authoritative for ticket-derived results.

## API and data docs

- [`API_CONTRACT.md`](API_CONTRACT.md): paths, DTOs, examples, validation, statuses, and CORS/base URL notes.
- [`DATASET_DOCUMENTATION.md`](DATASET_DOCUMENTATION.md): route/stop provenance, fixture counts, coordinates, and simulated cases.

The REST API includes application health, paginated bus/route/stop listings, route details and ordered stops, bus detail and journey search, trip-scoped ticket-derived occupancy, latest recorded bus location, and simulated ETM ticket ingestion. `GET /api/health` confirms only that the application responds; it does not verify PostgreSQL connectivity. `GET /api/buses/{busId}/location` returns the latest stored row, labels its source, and marks it stale after 15 minutes. No location returns 404; coordinates outside geographic bounds or inconsistent records return 409. The route detail response is the existing `RouteDto` (route metadata and first/last stop IDs); ordered stops are retrieved separately. The current stop model has no stop-code field, so the API uses stable stop IDs instead of inventing codes.

### Passenger ATM simulation booking

`POST /api/atm/bookings` accepts `idempotencyKey`, `tripId`, `busId`, `boardingStopId`, `destinationStopId`, and a positive `passengerCount`. It returns HTTP 201 with a server-generated booking reference, `bookingStatus: CONFIRMED_SIMULATION`, `dataOrigin: SIMULATED`, and `boardingStatus: NOT_BOARDING_EVIDENCE`. It does not accept dates, schedules, fares, payment, passenger identity, seats, or seat numbers because the backend has no authoritative source/model for them. The only accepted demo run identifier is `SIM-TRIP-{busId}-DEMO-01`, matching the deterministic simulation seed convention; it is not a canonical service run.

Booking checks are transactional and acquire the same pessimistic bus-row lock used by simulated ticket ingestion. Capacity is checked at every route order using existing same-trip ticket journeys plus confirmed same-trip bookings on `[boardingOrder, destinationOrder)`. A confirmed reservation is not added to ticket-derived occupancy and does not prove boarding. A simulated ETM ticket request may optionally include `bookingReference`; the service requires an exact bus/trip/segment/quantity match, links one ticket event, and moves the booking to `BOARDING_RECORDED_SIMULATION`. That simulated state transition avoids counting the same reservation and linked ticket twice; it still does not verify physical boarding. Unlinked ticket events leave reservations intact. Repeating the same booking request with the same key returns the original receipt; reusing a key with a different payload returns HTTP 409. Reservations have no cancel, expiry, or payment lifecycle. `V6__passenger_bookings.sql` is an unexecuted draft with the booking status and nullable unique ticket link. The endpoint remains unauthenticated and simulation-only.

### Trip-context schema update

The ticket model now includes a nullable `trip_id` column so existing records remain readable. Hibernate `update` may add the column in local development. Existing PostgreSQL databases should apply [`db/migration/V1__ticket_trip_context.sql`](db/migration/V1__ticket_trip_context.sql) to backfill only the known simulated fixture IDs and add the query index; the script is additive and repeatable. Production remains on `ddl-auto=validate`, so apply the migration through the reviewed deployment process before upgrading the application. Unrecognized historical tickets remain unassigned and are never silently mixed into an estimate. No database migration was executed automatically.

The service has no authentication in this phase and is intended only for local development.
