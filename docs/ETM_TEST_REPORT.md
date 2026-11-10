# SafarSetu ETM Test and Verification Report

**Audit date:** 2026-10-26. This report records source/test inspection only; no tests or live integrations were run for this design pass.

## Source/data verification

- `ETM/` is a Microsoft Cloud Files directory reparse point (tag `0x9000601a`); local recursive listing has no files. Vendor, device, event shape, and data cannot be tested until cloud-only contents are made available. Originals were not hydrated or changed.
- Current source defines simulated ticket ingestion, trip-string-scoped interval occupancy, routes/stops/buses, location points, and snapshots. No trip/run entity, device mapping, source event ledger, arrival, alighting lifecycle, cancel/refund model, authentication, or ATM booking entity exists.
- No PostgreSQL connection/schema inspection was performed. Do not interpret entity annotations or mocked service tests as proof of actual deployed DDL or database transaction behavior.

## Existing tests inspected

- `OccupancyCalculatorTest`: tests inclusive boarding/exclusive destination behavior, intermediate alighting while through passengers remain, party counts, route bounds, duplicate IDs, and capacity overflow using an in-memory calculator.
- `TicketServiceTest`: Mockito-based service tests cover duplicate ticket/idempotency keys, boarding after destination, stops outside the route, passenger-capacity violation, and trip scoping.
- `TicketValidationTest` and `RestApiControllerTest`: standalone MockMvc tests cover request validation, 201 simulated receipt shape, and API behavior with mocked services.
- No `@SpringBootTest`, `@DataJpaTest`, Testcontainers, or PostgreSQL-backed integration/concurrency test was found in the scanned backend tests. The bus-row locking path is therefore not verified against PostgreSQL here.
- Existing tests do not cover provider parsing, verified external-ID mapping, real-source provenance, event-sequence replay/out-of-order handling, cancellation/refund, arrival, idempotent alighting, booking conflicts, authentication, or database rollback under failure.

The historical audit reported a 52-test Maven run using Mockito; that historical run is not a fresh run for this audit and is not evidence of live database integration. No current test result is claimed here.

## Required tests before live ingestion

1. Parser/adapter tests from sanitized real vendor samples, including missing optional fields, timezone/offset, malformed records, vendor version changes, and file encoding.
2. Mapping tests for exact verified provider/device/bus/route/stop/trip IDs; unknown and ambiguous identifiers must be quarantined, not fuzzy-matched.
3. API validation tests for event types, timestamps, route sequence, positive counts, idempotency, exact replay, and conflicting duplicate payloads.
4. Occupancy tests for different passengers boarding/alighting at an intermediate stop; a party whose destination is that stop is released downstream while through passengers remain onboard.
5. Event ordering tests for delayed, replayed, duplicate, skipped, and backward-sequence events; corrections must preserve audit history.
6. Arrival tests for run/route/stop validation, duplicate arrival, backward stop, eligible alighting once, and no release on timer/GPS-only proximity.
7. Provenance tests ensuring current demo endpoint is always `SIMULATED`, real-source events can only be marked after authenticated mapping, and ticket sales/ATM bookings are not observed boardings.
8. PostgreSQL integration tests against a disposable explicitly configured database for migration validation, uniqueness/idempotency constraints, `SELECT … FOR UPDATE` behavior, transaction rollback, and concurrent capacity checks. These have not been run.
9. Security tests for authentication/authorization, device revocation, request limits, and redaction of credentials/PII.
10. Flutter API-mode tests for source labels, unknown/stale states, refresh after a successful accepted event/arrival, and no fallback to mock data. The existing app currently has no ETM submit flow.

## Current test-status summary

| Area | Status |
|---|---|
| Source inspection | Completed for current API/entity/service/controller/test and Flutter integration files |
| Local ETM data | Unavailable; no files enumerated from cloud-files placeholder |
| Unit/MockMvc tests in this audit | Not run |
| PostgreSQL integration/concurrency | Not verified; no DB connection used |
| Live ETM vendor/device | Not connected or configured |
| Arrival/alighting event processing | Not implemented; therefore not tested |
| Dashboard refresh after event | Not implemented/tested; existing passenger details load from GET on open and expose retry only on error |
| ATM booking reconciliation | Future design only; no booking model exists |

## Gate for test execution

After source samples, mapping rules, trip/arrival design, and authentication are approved, implement mocked tests first. Then provision/identify a disposable non-production PostgreSQL instance, back it up if it contains data, apply only approved migrations, and run integration/concurrency tests. Never test against a user or production database. Do not claim an ETM integration pass until a real provider sample/connection and expected event outcome are verified.

## Final product completion addendum — 2026-10-26

- Existing Flutter app: `flutter analyze` clean; 34 tests passed with `flutter test --no-test-assets`.
- Separate ATM Flutter app: `flutter analyze` clean; 4 tests passed.
- Spring Boot: offline Maven test run completed with 67 tests, 0 failures, 0 errors, 0 skipped. This includes service tests for booking idempotency, segment capacity across bookings and ticket events, route boundaries, and standalone MockMvc validation/receipt checks.
- PostgreSQL tests: not run. Port 5432 had no listener; `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` were unset. These results are not database integration or real concurrent transaction evidence.
- ETM provider/device: still unavailable; no live hardware or vendor-format parsing is verified.
