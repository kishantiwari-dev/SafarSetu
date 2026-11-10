# SafarSetu Final Product Readiness Report

**Assessment date:** 2026-10-26  
**Release decision:** **NOT READY FOR PRODUCTION**  
**Scope:** Source, automated tests, web release builds, SDK access, local service availability, migration drafts, and security review. No database was started, inspected, or modified.

## Executive status

The existing Flutter app and the separate ATM kiosk now pass static analysis and their available Flutter tests. The Spring Boot backend compiles and its unit/MockMvc suite passes. Both Flutter Web release builds were produced. A new simulation-only booking endpoint and kiosk workflow share route-segment capacity checks with simulated ticket ingestion.

End-to-end API and PostgreSQL behavior remain unverified. PostgreSQL port 5432 and backend port 8080 had no listeners; the database environment variables were unset. V2–V6 are draft SQL only, there is no migration runner, and no migrations or Hibernate schema updates were run. The API has no authentication. Real ETM vendor data remains unavailable. Edge was not opened for a live backend-connected manual test. A final verification attempt on 2026-10-26 found that the installed Flutter command again stalled silently; therefore previously recorded Flutter test/build results are historical checks and do not verify the latest ETM booking-reference UI change.

## Readiness matrix

| Area | Classification | Evidence / remaining condition |
|---|---|---|
| Existing passenger Flutter app | **IMPLEMENTED; LATEST CHANGE NEEDS RECHECK** | The prior root Flutter check was clean and 34 tests passed with `flutter test --no-test-assets`; a release Web build succeeded before the latest ETM booking-reference UI change. A fresh analyzer attempt stalled. Browser and live backend flows were not manually exercised. |
| API-mode bus search and details | **IMPLEMENTED BUT NOT VERIFIED** | Mock/API repository tests pass and API mode does not fall back to mock data. No live backend/database was available. |
| Occupancy and crowding presentation | **IMPLEMENTED AND VERIFIED** | UI presents seats-left percentage as the summary, distinguishes ticket-derived estimates from observed counts, and withholds occupancy without fresh/simulated trip-scoped data. Relevant Flutter tests pass. |
| ETM simulation workflow | **IMPLEMENTED; LATEST CHANGE NEEDS RECHECK** | Ticket, simulated arrival, expected alighting, idempotent retry, occupancy refresh, and optional booking-reference reconciliation are implemented. The backend suite passed after reconciliation changes; the latest Flutter linkage UI change was not rechecked due to the SDK stall. No HTTP/DB-backed run or physical ETM verification occurred. |
| ATM passenger kiosk | **IMPLEMENTED BUT NOT VERIFIED** | Separate web Flutter app in `ATM/`, API-only stop/bus/booking flow, quantity selection, review, receipt, retry key, and clear simulation labels. Four tests, analysis, and release Web build pass. No live booking was created. |
| Booking capacity/idempotency backend | **IMPLEMENTED BUT NOT VERIFIED** | Same-bus pessimistic lock is shared with ticket ingestion; service tests cover overlapping segment capacity, trip scoping, retries, and reservation/ticket interaction. MockMvc validates the API contract. PostgreSQL transaction and concurrency behavior are unverified. |
| PostgreSQL persistence and schema | **BLOCKED BY EXTERNAL DEPENDENCY** | Port 5432 not listening; `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` unset; no `psql`/`pg_ctl` command found; service-manager query was unavailable. No database target/schema was inspected. |
| Draft migrations V2–V6 | **IMPLEMENTED BUT NOT VERIFIED** | Reviewed and V6 aligned to the booking entity. Drafts are unexecuted; no migration tool or target schema validation exists. |
| Real ETM integration | **BLOCKED BY EXTERNAL DEPENDENCY** | `ETM/` remains a Cloud Files reparse point and yielded no locally inspectable vendor material. No device/provider mapping is verified. |
| Authentication/authorization | **NOT IMPLEMENTED** | All current API endpoints, including simulated ETM ingestion and ATM booking, are unauthenticated. Local prototype only; not safe for public exposure. |
| Live Microsoft Edge workflow | **NOT VERIFIED** | Release artifacts were built, but Edge was not opened and no live browser/API booking journey was executed. |

## Implemented behavior and architecture

### Existing passenger application

- Keeps the current SafarSetu app in the project root and the separate kiosk in `ATM/`.
- Keeps the existing explicit mock/API data-source choice. API mode never silently falls back to mock data.
- Loads backend stops and bus searches, route details, trip-scoped occupancy, and simulated location through the existing Spring API.
- Rejects stale/unknown or unscoped occupancy as a usable estimate. The search summary leads with estimated seats likely left; it does not present raw occupied/capacity as the headline.
- Keeps favorites and recent journey storage local to the browser/device; they are not synchronized to an account or backend.
- Retains ETM ticket/arrival simulation navigation and labels simulated events and expected alighting as estimates, not physical counts.

### ETM simulation

The existing Flutter app loads active `SIMULATED` buses and their ordered route stops. A ticket event posts a ticket ID, idempotency key, bus, ordered segment, positive passenger count, UTC timestamp, and string `tripId` to `POST /api/etm/tickets`. A simulated arrival posts event, trip, bus, stop, and timestamp to `POST /api/etm/simulated/arrivals`. Accepted operations display backend receipts and refresh occupancy for that same bus, stop, and trip. An occupancy refresh failure does not erase an accepted receipt.

Occupancy continues to use `[boardingStopOrder, destinationStopOrder)`. Arrival alighting values are ticket-derived simulated expectations; neither booking confirmation nor route progression proves that anyone physically boarded or alighted.

### ATM booking flow and data path

1. `ATM/` loads `GET /api/stops?page=0&size=100`.
2. The passenger chooses boarding and destination stops; the kiosk requests `GET /api/buses/search` and presents only active `SIMULATED` buses.
3. The passenger selects a bus and quantity (1–20), reviews the route, and confirms a clearly labeled simulated booking.
4. The kiosk sends one `POST /api/atm/bookings` with a stable retry key and synthetic demo trip context.
5. The backend locks the bus row, validates route order, and checks every route segment against same-trip ticket journeys plus confirmed reservations. The server returns a stable booking reference and status.
6. The receipt explicitly says the booking is not evidence of boarding. No fare, payment, scheduled date/time, seat number, cancellation, or timeout is fabricated.

The kiosk derives the synthetic trip identifier `SIM-TRIP-{busId}-DEMO-01`, which matches the existing deterministic seed convention. This is not a canonical real service run. Same-key same-payload retries return the original receipt; reusing a key with changed payload conflicts. Confirmed reservations remain reserved because cancellation/expiry is not modeled. An ETM simulation event may optionally include the booking reference. The backend links it only when bus, trip, journey segment, and passenger count match; it then records `BOARDING_RECORDED_SIMULATION` and no longer counts that reservation separately against capacity. This is a simulation reconciliation only and does not verify physical boarding. Unlinked ETM events leave the reservation reserved.

### Booking API example

```http
POST /api/atm/bookings
Content-Type: application/json
Idempotency-Key: atm-demo-retry-001
```

```json
{
  "idempotencyKey": "atm-demo-retry-001",
  "tripId": "SIM-TRIP-BUS-SIM-001-DEMO-01",
  "busId": "BUS-SIM-001",
  "boardingStopId": "KP_II",
  "destinationStopId": "PARI_CHOWK",
  "passengerCount": 2
}
```

The response is HTTP 201 with `bookingReference`, `bookingId`, journey details, `bookingStatus: CONFIRMED_SIMULATION`, `dataOrigin: SIMULATED`, and `boardingStatus: NOT_BOARDING_EVIDENCE`. Capacity conflicts return structured HTTP 409 errors. No live request was sent in this assessment.

## Database and migration review

- Backend configuration requires `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`; this assessment did not print or read any secret value.
- Dev defaults to Hibernate `update` and insert-only simulated seeding. This assessment did not start the backend, so neither schema nor data was changed.
- The base profile validates schema. The new `SimulatedTripArrival` and `PassengerBooking` tables therefore require the corresponding reviewed database schema before a validated startup.
- `backend/db/migration/V2__simulated_trip_arrivals.sql` matches the simulated arrival record shape; V3 adds an optional relational service-run mapping without replacing `tickets.trip_id`; V4/V5 are provider mapping and normalized event-ledger drafts pending real vendor evidence; V6 is an additive booking schema with unique reference/idempotency keys and trip-segment lookup index.
- V6 also contains a draft `passenger_booking_events` table that is not yet mapped by the JPA application. Do not assume it is active. It also adds the nullable unique `tickets.booking_id` link needed to reconcile a matching simulated ETM ticket with a kiosk reservation.
- There is no Flyway/Liquibase dependency or migration executor in `backend/pom.xml`. V2–V6 were not executed. No database was created, reset, migrated, or queried.
- Mock tests do not verify PostgreSQL DDL, persistence, transaction rollback, or the actual `SELECT … FOR UPDATE` concurrency behavior.

## Verification results

| Check | Result |
|---|---|
| Flutter SDK | `flutter --version` completed within 30 seconds when run with access to the installed SDK; Flutter 3.47.2 stable, Dart 3.13.2. |
| Existing app formatting | `dart format lib test`; 33 files checked/formatted, 17 files changed by formatting. |
| Existing app analysis | `flutter analyze`: no issues. |
| Existing app tests | `flutter test --no-test-assets`: 34 passed, 0 failed. |
| ATM dependency resolution | `flutter pub get`: succeeded. |
| ATM formatting | `dart format lib test`: 5 files checked, 1 changed by formatting. |
| ATM analysis | `flutter analyze`: no issues. |
| ATM tests | `flutter test`: 4 passed, 0 failed. |
| Backend compile and tests | `mvn -o -DargLine="-javaagent:<cached Mockito jar>" test`: 69 tests, 0 failures, 0 errors, 0 skipped; build success. |
| Root Flutter Web release | `flutter build web --release --output build_release_audit_retry`: succeeded before the latest ETM booking-reference UI change; rebuild pending. |
| ATM Flutter Web release | `flutter build web --release --output release_web_audit`: succeeded. |
| Default root Flutter test command | First attempt could not delete `build/unit_test_assets`; see toolchain and filesystem note below. |
| PostgreSQL integration | Not run: PostgreSQL unavailable/unconfigured. |
| Backend HTTP health/API | Not run: backend not started; port 8080 had no listener. |
| Browser end-to-end | Not run: Edge was not opened for this task. |

The backend test run was subsequently refreshed after adding the optional ETM-to-booking link: 69 tests passed, with 0 failures, 0 errors, and 0 skipped. A later Flutter analyzer refresh stalled without output for 40 seconds and was stopped through that diagnostic session; no unrelated Flutter or Edge process was terminated. The current Flutter tree, including that latest UI change, therefore needs a fresh bounded analyze/test/build run from a context where the SDK cache lock is writable.

The backend suite uses Mockito and MockMvc. It is not a PostgreSQL integration or real concurrent transaction test. The Flutter suites use fake gateways/HTTP clients and widgets; they do not prove a live server/database workflow.

## Toolchain and filesystem finding

The installed Flutter wrapper calls `bin/internal/shared.bat`, which attempts to acquire `bin/cache/flutter.bat.lock` by opening the lock file for write. The SDK ACL grants the Codex sandbox identity read/execute access but not write access. The wrapper suppresses errors around the lock open and loops back to acquisition, which explains the earlier silent hang in the sandbox. A bounded version check outside that restricted context completed successfully; no ACL or system setting was changed.

The default root `flutter test` also reported it could not delete the pre-existing `build/unit_test_assets`. Inspection showed the path is a OneDrive reparse-point directory with an explicit `Everyone` deny for `DeleteSubdirectoriesAndFiles`. No project files or SDK cache were deleted. The documented `--no-test-assets` run passed the complete root suite.

## Security, external dependencies, and known limitations

- No API authentication or authorization exists. Restrict backend use to local development; do not expose this API to the internet or trusted operational networks.
- The simulated ETM ticket ingestion and arrival endpoints are unauthenticated. No vendor device identity, signature, replay-window policy, or real source validation exists.
- The ATM booking API is also unauthenticated. It has idempotency and server-side capacity checks for simulation but no customer identity, payment, cancellation, expiry, refund, receipt lookup, or production reservation lifecycle.
- The backend `/api/health` is process liveness only; it does not check PostgreSQL readiness.
- No PostgreSQL installation/service could be confirmed with available read-only tooling: port 5432 did not listen, `psql`/`pg_ctl` were not found in PATH, the Windows service query was unavailable, and database environment variables were absent.
- `ETM/` is still a Cloud Files reparse point with no locally visible vendor files. Real ETM integration and verified mappings remain blocked.
- A `.git` directory is absent at the project root, so a Git status/diff baseline could not be recorded. Existing `PROJECT_PLAN.md` files in `ATM/` and `passenger_kiosk_app/` have matching SHA-256 hashes; the original plan was preserved.
- A prior incomplete web build output created during this assessment was removed after verifying the path had not existed beforehand. The two successful release outputs remain available.

## Exact safe next steps

1. Identify and start the intended **existing local development PostgreSQL service** outside this task, then verify port 5432. Do not initialize a new cluster or use production.
2. Identify the exact development database/schema, make and verify a backup/recovery plan, and inspect current tables/columns. Supply database connection credentials through a masked PowerShell prompt; do not put them in source or command history.
3. Select/configure a migration tool, compare the V2–V6 drafts with that schema, decide how to handle the unmapped `passenger_booking_events` table, test the approved migration sequence on a disposable database, and obtain explicit approval before applying it to the target database.
4. Start backend with reviewed local settings (`DDL_AUTO=validate`, `SEED_DEMO_DATA=false`) and verify database readiness separately from `GET /api/health`; then call stops/search/booking endpoints against that database.
5. Launch the existing app in API mode and the kiosk from `ATM/` in Edge. Verify a simulated bus journey, booking retry/capacity conflict, ETM ticket/arrival flow, and receipt screens through the live API.
6. Before any non-local release, implement and review authentication/authorization, booking cancellation/expiry/payment policy, operational logging/abuse limits, and real ETM mapping from supplied vendor evidence.

### Release readiness

The project is a **tested local simulation prototype**, not a production-ready release candidate. Production release is blocked by PostgreSQL/schema verification, live end-to-end checks, missing API security, booking lifecycle decisions, and the unavailable real ETM provider contract.
