# SafarSetu + ETM — Complete Project, Database, Data, and Integration Audit

**Audit date:** 2026-10-26  
**Project:** `C:\Users\PC\OneDrive\Desktop\safersetu`  
**Scope:** read-only inspection of project source/configuration, ETM directory, available local runtime state, and existing tests. This report was the only requested file created. No source/configuration or database data was changed.

## Executive summary

This checkout contains a Flutter passenger-facing prototype and a Spring Boot API with simulated bus, ticket, location, and occupancy data. The Flutter app defaults to mock data; API mode is an explicit opt-in. The backend has no production ETM adapter, authenticated passenger identity, trip/run model, booking/seat inventory, or confirmed live database connection. The `ETM` directory is an empty cloud-files placeholder in this checkout, so its remote contents cannot be assessed from this machine without hydration.

PostgreSQL was not reachable at `127.0.0.1:5432`; the backend was not listening at port 8080. PostgreSQL service-manager inspection was denied by Windows, and common installation paths and command-line tools were absent. Therefore no claim is made about database schema/data currently present. Backend tests did pass: 52 tests, 0 failures/errors/skips, with the local Mockito agent supplied to work around self-attachment. They use mocks and do not prove PostgreSQL integration. Flutter analyze/test could not be completed in this OneDrive checkout; see verification notes.

## 1. Repository and file inventory

Top-level folders include `.github`, `assets`, `backend`, `docs`, `ETM`, `lib`, `test`, and `web`. There is no root README and no `.git` directory in the inspected checkout. Useful project documentation is in `backend/README.md`, `backend/API_CONTRACT.md`, `backend/DATASET_DOCUMENTATION.md`, `docs/FLUTTER_MOCK_DATA.md`, and `PROJECT_CONTEXT.md`.

A source-oriented inventory (excluding build/cache/vendor output) found 102 files: 27 Dart, 46 Java, six Markdown, one SQL migration, one `.env.example`, and other project configuration/assets. No CSV/TSV/spreadsheet, database dump, or ETM dataset was present in the hydrated files. `web/manifest.json` is the web-app manifest, not transport data.

`ETM/` enumerates zero files and zero subdirectories. It is a directory reparse point with the Microsoft cloud-files tag. This means the local checkout does not reveal whether cloud-only files exist remotely; do not infer that the user's remote ETM folder is truly empty. No hydration or writes were attempted.

## 2. Stack and configuration

- Flutter cache reports Flutter 3.47.2 stable / Dart 3.13.2. `pubspec.yaml` supports Dart `>=3.3.0 <4.0.0`; direct dependencies include `http`, `flutter_map`, `latlong2`, `shared_preferences`, and `url_launcher`.
- Backend uses Spring Boot 4.1.1, Java 21, Maven 3.9.16. Temurin JDK 21.0.8 is available.
- PostgreSQL connectivity check to `127.0.0.1:5432`: **failed/not listening**. Port 8080: **not listening**. `psql`, `pg_ctl`, `postgres`, Docker, and Podman were not found on PATH. Common PostgreSQL installation directories were absent. Windows service enumeration failed because access to the Service Control Manager was denied; installation/service presence is therefore not fully determined.
- No `DB_*` or `SPRING_*` database environment variables were present in the inspected process environment. Secret values were not displayed or copied.
- `backend/src/main/resources/application.yml` takes URL, username, and password from environment variables. Dev profile defaults to Hibernate DDL `update`, demo seeding enabled, and local CORS. Production configuration uses `validate`, disables seeding, requires `sslmode=verify-full`, and takes allowed origins from environment. `.env.example` is illustrative; Spring does not automatically load it. No Docker Compose, Flyway, or Liquibase configuration was found.
- The sole migration, `backend/db/migration/V1__ticket_trip_context.sql`, is not wired to an observed migration runner. Project context describes it as adding nullable `tickets.trip_id`, backfilling known synthetic ticket IDs, and adding an index. This audit did not execute it.

## 3. Database model and current-state limits

The source defines seven JPA entity tables. Live existence/counts/schema were not inspected because PostgreSQL was unavailable.

| Table/entity | Source-defined role and notable properties |
|---|---|
| `routes` / Route | route identity, display/name metadata |
| `stops` / Stop | stop identity/name and approximate coordinates |
| `buses` / Bus | bus/fleet identifiers, route relation, seating and total passenger capacities, current status |
| `route_stops` / RouteStop | ordered stop sequence for a route; route/stop association |
| `tickets` / Ticket | synthetic ticket/event identity, bus/route/stops, passenger count, boarded time, nullable string `trip_id`; no FK to a trip entity |
| `bus_locations` / BusLocation | bus position and observed timestamp |
| `occupancy_snapshots` / OccupancySnapshot | stored occupancy samples |

There are no source entities for users, trips/runs, bookings, assigned seats, physical seat maps, ETM devices, or arrival/boarding events. In particular, `tickets.trip_id` is a nullable string, not a relational trip context. Entity annotations and constraints are source definitions only, not proof of the existing database schema.

### Relationship sketch

```text
Route 1 ── * RouteStop * ── 1 Stop
  │
  └── * Bus ── * Ticket
       ├── * BusLocation
       └── * OccupancySnapshot
Ticket also carries board/alight stop context and an optional trip_id string.
```

Actual foreign-key behavior should be confirmed against the live schema once a database is accessible.

## 4. Seed/demo data profile

`DevelopmentDataSeeder.java` defines insert-only demo rows keyed by stable IDs; it does not clear tables or update existing rows. Dev defaults enable seeding. Production defaults disable it. **Actual database row counts are unknown** because no database connection was available.

Source seed profile: 22 stops (all marked approximate), 9 routes, 52 route-stop links, 13 simulated buses, 23 synthetic ticket events (18 `T-SIM-*`, five `T-DEMO-*`), 19 bus location rows, and 13 occupancy snapshots. Bus `fleetCode` is set to the synthetic bus ID. The seed does not represent verified ETM records.

### Seed bus inventory

| Bus | Route | Seats / total passenger capacity | Seed ticket events | Locations |
|---|---:|---:|---:|---:|
| BUS-SIM-001 | 001 | 35 / 50 | 4 | 3 |
| BUS-SIM-002 | 002 | 40 / 55 | 3 | 3 |
| BUS-SIM-003 | 003 | 40 / 55 | 3 | 3 |
| BUS-SIM-004 | 004 | 30 / 45 | 2 | 3 |
| BUS-SIM-005 | 005 | 35 / 50 | 0 | 0 |
| BUS-SIM-006 | 006 | 32 / 48 | 2 | 3 |
| BUS-SIM-007 | 007 | 38 / 52 | 2 | 3 |
| BUS-SIM-008 | 008 | 35 / 50 | 2 | 1 (old) |
| BUS-SIM-009 | 001 | 50 / 50 | 1 | 0 |
| BUS-SIM-010 | 001 | 50 / 50 | 1 | 0 |
| BUS-SIM-011 | 009 | 50 / 50 | 1 | 0 |
| BUS-SIM-012 | 009 | 50 / 50 | 1 | 0 |
| BUS-SIM-013 | 009 | 50 / 50 | 1 | 0 |

### Seed routes and ordered stops

| Route | Stop sequence |
|---|---|
| 001 | BOTANICAL_GARDEN → SECTOR_18 → SECTOR_62 → KP_II → PARI_CHOWK → ALPHA_1 |
| 002 | SECTOR_62 → SECTOR_51 → SECTOR_76 → KP_II → DELTA_1 → GNIDA |
| 003 | GAUR_CITY → KISAN_CHOWK → GREATER_NOIDA_WEST → SECTOR_51 → SECTOR_62 |
| 004 | KASNA → SHARDA → GBU → SURJPUR → DELTA_1 → PARI_CHOWK |
| 005 | SECTOR_51 → SECTOR_76 → SECTOR_137 → SECTOR_142 → SECTOR_148 → KP_II |
| 006 | DADRI_RAIL → GBU → KASNA → KP_II → PARI_CHOWK → DEPOT |
| 007 | KP_II → PARI_CHOWK → ALPHA_1 → DELTA_1 → GNIDA → DEPOT |
| 008 | SECTOR_18 → BOTANICAL_GARDEN → SECTOR_51 → GREATER_NOIDA_WEST → GAUR_CITY |
| 009 | ALPHA_1 → PARI_CHOWK → KP_II → SECTOR_62 → SECTOR_18 → BOTANICAL_GARDEN |

### Approximate source coordinates

These are demo coordinates and are explicitly approximate, not surveyed/ETM-confirmed positions.

| Stop | Latitude | Longitude | Stop | Latitude | Longitude |
|---|---:|---:|---|---:|---:|
| BOTANICAL_GARDEN | 28.5647 | 77.3340 | SECTOR_18 | 28.5708 | 77.3261 |
| SECTOR_62 | 28.6270 | 77.3725 | SECTOR_51 | 28.5834 | 77.3730 |
| SECTOR_76 | 28.5678 | 77.3761 | SECTOR_137 | 28.5065 | 77.4050 |
| SECTOR_142 | 28.4939 | 77.4107 | SECTOR_148 | 28.4774 | 77.4170 |
| KP_II | 28.4578 | 77.5000 | PARI_CHOWK | 28.4652 | 77.5080 |
| ALPHA_1 | 28.4712 | 77.5070 | DELTA_1 | 28.4772 | 77.5140 |
| GNIDA | 28.4740 | 77.5030 | KASNA | 28.4070 | 77.5050 |
| SHARDA | 28.4720 | 77.4830 | GBU | 28.4190 | 77.5300 |
| SURJPUR | 28.5200 | 77.4850 | DADRI_RAIL | 28.5525 | 77.5545 |
| GAUR_CITY | 28.6070 | 77.4350 | KISAN_CHOWK | 28.6130 | 77.4490 |
| GREATER_NOIDA_WEST | 28.5950 | 77.4450 | DEPOT | 28.4510 | 77.5350 |

## 5. Occupancy, ticket, and overcrowding semantics

`OccupancyCalculator` derives passenger load at route order `q` from ticket intervals: a ticket counts while `boardOrder <= q` and `destinationOrder > q`. This models a leg interval; ticket wall-clock time does not establish actual position or arrival. It is a projection from synthetic ticket records, not a sensor/ETM-confirmed headcount.

`TicketService` validates ticket IDs/idempotency, positive passenger count, route and stop order, timestamps no more than 60 seconds in the future, and total passenger capacity at route stops. It uses a transaction and a pessimistic lock on the bus row. PostgreSQL lock behavior has not been exercised here. Successful simulated ingest reports `dataOrigin=SIMULATED`.

Two source/documentation mismatches need resolution:

1. `BusService.java` computes crowd category using `seatingCapacity`; `backend/API_CONTRACT.md` says the denominator is `totalPassengerCapacity`.
2. Provisional seat estimates clamp `seatingCapacity - passengers` at zero in code; API contract says negative values are returned, while dataset docs say the value is clamped.

Ticket validation uses total passenger capacity while the seat estimate uses seating capacity. Define whether standing passengers contribute to crowd status and what “seats likely left” means; expose these values separately so a passenger-facing seat estimate is not confused with total occupancy. Stored snapshots are seeded but are not authoritative inputs to the described route-segment calculation.

## 6. Backend API inventory

All listed endpoints are defined in source; they were not called because the backend was not running. No authentication was found in the inspected API. Health returns `{status: UP}` and does not check database connectivity, so it is a process liveness check, not a DB readiness check.

| Method and path | Purpose |
|---|---|
| `GET /api/health` | health/liveness response |
| `GET /api/buses` | bus listing |
| `GET /api/buses/{busId}` | bus details |
| `GET /api/buses/search` | search by journey context |
| `GET /api/routes` | route listing |
| `GET /api/routes/{routeId}` | route details |
| `GET /api/routes/{routeId}/stops` | ordered route stops |
| `GET /api/stops` | stop listing |
| `GET /api/buses/{busId}/occupancy` | occupancy, optional stop/trip context |
| `GET /api/buses/{busId}/location` | latest bus location |
| `POST /api/etm/tickets` | simulated ticket-event ingestion |

There is no booking, seat-hold, seat-assignment, trip/run, or arrival-event endpoint. `/api/etm/tickets` is unauthenticated simulated ingestion, not a passenger booking API. Stops/search/occupancy behavior could not be validated against a running DB or API.

## 7. Flutter application and integration

`lib/main.dart` starts a local LoginScreen flow. The frontend contains Home/Search/Trips/Profile and bus details, with favourites and recent journeys stored locally using `shared_preferences`; there is no account sync. No booking flow or seat picker was found.

The app defaults to its mock repository. API-backed mode requires `SAFARSETU_DATA_SOURCE=api` and uses `http://localhost:8080/api` by default. `ApiBusRepository` requests stops, search, occupancy, bus detail, route stops, and location. It does not send ticket/booking writes. API mode does not silently fall back to the mock repository. Thus the ordinary launch can look populated while not using the backend; verify the selected source when evaluating integration.

`docs/FLUTTER_MOCK_DATA.md` is stale in places: it claims reverse routes return no results and describes nine scenario records; current `MockBusRepository` has nine route arrays including `SIM-GN-009`, and synthesizes three generic `BUS-DEMO-A/B/C` options for valid ordered pairs (18/32/48 passengers against 50 seats). Some special bus detail cases in the doc refer to BUS-SIM-005/008, which normal search does not return. `PROJECT_CONTEXT.md` contains dated historical results, not fresh verification for this audit.

No ETM UI, device transport, vendor payload parser, device identity, external ticket ID mapping, fleet-code crosswalk, retry/outbox, or ETM data provenance pipeline was found. A future integration needs a verified mapping between actual ETM bus/device identifiers and app buses, plus event semantics and deduplication rules.

## 8. ETM integration assessment

The inspected application models ticket-like events as simulated passenger counts attached to buses and route stops. It does not model a real service run/trip with a service date and bus assignment. A bus ID or route ID alone is not adequate context for reconciling ETM activity across repeated journeys. No files under the locally enumerated `ETM/` placeholder could be parsed, so vendor, format, schema, encoding, data quality, and historical completeness remain unknown.

Before implementation, inventory actual ETM samples and document: device/vendor and protocol; stable device and fleet identifiers; trip/run reference; timestamp/time zone; boarding/alighting event shape; ticket/passenger count and cancellation/refund semantics; duplicate/replay behavior; route/stop codes and crosswalk; coordinate provenance; offline sync ordering; and privacy/retention constraints. Preserve raw source IDs and provenance while mapping to canonical entities. Do not treat synthetic seeded identifiers as verified production IDs.

## 9. Booking and seat-allocation architecture guidance

A credible booking system needs a `Trip`/`Run` instance (bus, route, service date, planned/actual times and operational status) and a reservation lifecycle (hold, expiry, confirm, cancel/refund). Add passenger identity/authentication and authorization, idempotency keys, payment boundary if applicable, and auditable booking events. Seat inventory can be represented by physical seats assigned to non-overlapping route-leg intervals or by segment capacity; allocation must be transactional to prevent concurrent overbooking. For leg interval `[boardOrder, alightOrder)`, reservations on adjacent legs may reuse a seat, while overlapping intervals may not. If the product sells unassigned capacity, enforce per-segment limits atomically instead.

Keep live occupancy separate from booked seats and from total passenger load. ETM events can update observed boarding/alighting counts, but should not silently rewrite reservations. Initially, ordinary polling can be sufficient; correctness depends first on run context, idempotent writes, and database concurrency controls. Add PostgreSQL-backed integration/concurrency tests before relying on the locking behavior.

## 10. Security, operational, and data-quality observations

- `/api/etm/tickets` is unauthenticated in the inspected configuration; do not expose as a production ingestion endpoint without authentication, authorization, and request validation/rate protection.
- Development profile enables schema update and demo seeding. Keep production on validated schema and disabled seeding; do not start a real DB against the dev profile without understanding its effects.
- Demo coordinates are approximate. Demo bus locations and ticket counts are synthetic and can be stale or internally inconsistent as live observations.
- Health endpoint does not establish DB readiness.
- No live PostgreSQL data, permissions, schema drift, backup/restore posture, or ETM ingestion health could be inspected.
- No full-stack browser verification was possible in this audit because services were not running and Flutter checks stalled in this checkout.

## 11. Verification and test results

| Check | Result | Evidence/limits |
|---|---|---|
| Source/config and docs inspected | Passed | Current checkout files inspected; ETM cloud placeholder is not hydrated |
| PostgreSQL port 5432 | Failed/unavailable | TCP connection refused/not listening; service manager access denied |
| Backend port 8080 / health/API | Not run | No backend process listening; health cannot be claimed |
| Maven test suite | Passed | `mvn -o '-DargLine=-javaagent:C:\Users\PC\.m2\repository\org\mockito\mockito-core\5.23.0\mockito-core-5.23.0.jar' test`; 52 tests, 0 failed/errors/skips. Mocks, not DB integration |
| `mvn -o test` without explicit agent | Stalled | Mockito self-attachment issue; rerun with local javaagent passed |
| Flutter analyze/test | Inconclusive | `flutter analyze --no-pub` and `flutter test --no-pub` stalled silently beyond 30 seconds and were interrupted |
| Direct `dart analyze lib test` | Failed before analysis | Dart CLI error: `Null is not a subtype of String` in `resolvedExecutable` |
| Browser/UI flows | Not tested | No application launch in this audit; no claims of search/favourites/recent/details/API integration passing |

Maven generated build output under `backend/target`; no database/server was started and no DB records were changed. No new tests were added.

## 12. Prioritized follow-up plan

1. Make the cloud-only ETM folder available locally or provide representative files. Inventory the vendor format without changing originals.
2. Verify the intended PostgreSQL installation/service and credentials outside source control; inspect database/schema/table counts with read-only queries. Never use the dev seeder as a substitute for a verified backup.
3. Add explicit trip/run context and canonical bus/fleet/device crosswalk before connecting ETM events.
4. Resolve crowd denominator and negative-seat estimate contract mismatch; define passenger-facing remaining-seat estimate separately from standing/total load.
5. Add authenticated, idempotent ETM ingestion with raw event provenance, duplicate/replay protection, validation, and observability.
6. Add booking and seat/segment inventory with transactional conflict prevention, then PostgreSQL integration and concurrency tests.
7. Update stale docs and add a DB readiness endpoint or readiness check.
8. Run Flutter analyze/test in a stable local checkout, start backend against verified PostgreSQL, explicitly launch API mode, then exercise UI and API flows in Edge.

## Appendix A — Safe next commands

From project root, first confirm the intended database exists and take a backup according to local operations policy. Keep secrets out of command-line literals and source. To prompt for a password without echoing it in PowerShell and run the backend in that same shell:

```powershell
$secure = Read-Host 'PostgreSQL password' -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', $secure).Password
$env:DB_URL = 'jdbc:postgresql://localhost:5432/<existing_database>'
$env:DB_USERNAME = '<existing_username>'
$env:DDL_AUTO = 'validate'
$env:SEED_DEMO_DATA = 'false'
Set-Location 'C:\Users\PC\OneDrive\Desktop\safersetu\backend'
mvn spring-boot:run
```

The placeholders must be replaced with the actual existing database/user after verifying them; no password should be placed in source or printed. Then, from a separate terminal, check health and actual project-defined API paths. A green `/api/health` alone does not prove database connectivity. For Flutter web with API mode, use the project’s supported launch configuration and verify the browser’s network requests actually reach `/api`; default mock mode is not evidence of backend integration.

## Appendix B — Open questions requiring real ETM/DB access

- What files and formats exist in the cloud-only `ETM/` directory, and which ETM vendor/device produced them?
- What is the authoritative PostgreSQL service, database name, schema, version, and backup policy?
- Which real bus, route, stop, trip, and device identifiers map to the synthetic app model?
- Are passenger counts based on validated boarding/alighting events, ticket sales, or manual estimates?
- Is the intended product unassigned capacity booking or named physical seat selection?
- What authentication, payment, cancellation, privacy, and retention rules apply?

---

**Audit conclusion:** source inspection and mocked backend tests are complete. A live database/API/ETM/browser integration audit remains unverified until PostgreSQL and backend access are available and the ETM placeholder is hydrated. This report does not claim otherwise.
