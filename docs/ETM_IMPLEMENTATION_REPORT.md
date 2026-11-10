# Simulation-only ETM workflow implementation report

Date: 2026-10-26

## Scope and baseline

The ETM path is simulation-only. The backend already accepted ticket journeys with an explicit `SIMULATED` data origin and calculated ticket-derived occupancy on the route interval `[boardingStopOrder, destinationStopOrder)`. No canonical service-run entity, arrival ledger, vendor parser, or device integration existed. The ETM directory is a Cloud Files reparse point whose contents were not locally available, so no vendor samples or mappings were assumed. PostgreSQL port 5432 had no listening socket during this run; no services or database were started or queried.

The existing Flutter application has API-backed read paths, but no operator ETM event flow. Adding a useful event submission UI would need a new operator workflow, so this phase documents that future UI instead of changing passenger screens. Flutter commands were not run.

## Implemented

- Added `POST /api/etm/simulated/arrivals`, a separate endpoint that accepts event, trip, bus, stop, and timestamp fields. Server-side source classification is always `SIMULATED`.
- Arrival processing locks the bus row, requires a SIMULATED bus, validates route membership and ordering, rejects duplicate event IDs, repeated stops, backwards stop progression, and backward timestamps.
- The stored alighting value is a derived count of SIMULATED tickets destined for that stop. The receipt labels it `SIMULATED_EXPECTED_ALIGHTING`; it is not a physical boarding/alighting observation.
- The response includes the existing trip-scoped occupancy projection at the arrival stop. Existing tickets and occupancy semantics are preserved; accepted arrivals do not rewrite tickets or claim verified physical arrival.
- Added mocked service tests for accepted arrivals, expected alighting, duplicate IDs, repeated/backwards arrivals, and off-route stops.
- Added SQL migration drafts V2–V6. No migration runner/dependency is configured, and none were executed.
- Added synthetic example events and a header-only mapping template under `docs/examples/etm_simulation/`. They are examples only and do not establish fleet mappings.

## Assumptions and limitations

- `tripId` remains a string. V2 arrival rows use `(bus_id, trip_id, stop_order)` uniqueness; canonical relational run references are only proposed in V3.
- Ticket-derived occupancy is an estimate of ticketed journeys, not an observed count. Expected alighting is likewise a derived simulation quantity.
- The new endpoint follows the current backend's unauthenticated API convention. Treat it as local development functionality; no production authentication or authorization is claimed.
- The ETM cloud placeholder did not expose local contents. No vendor format, device identity, fleet mapping, or actual ETM source has been verified.

## Verification

- PostgreSQL: not reachable on port 5432; no connection/query attempted.
- Backend tests: `mvn -o "-DargLine=-javaagent:C:\\Users\\PC\\.m2\\repository\\org\\mockito\\mockito-core\\5.23.0\\mockito-core-5.23.0.jar" test` completed successfully: 57 tests, 0 failures, 0 errors, 0 skipped. Tests use mocks; this is not a PostgreSQL integration test.
- Flutter analysis/tests: skipped because no Flutter UI was changed and prior Flutter CLI startup was unreliable.
- Migrations: not executed. Existing data was not deleted or rewritten by this work.

## Changed and created files

See the final report for the complete path list. Existing four ETM design documents and the earlier audit were preserved. `ATM/` and the Flutter passenger UI were not modified.

## Next UI flow (proposal)

A separately authorized operator screen could select a synthetic bus/trip, submit a ticket event or stop arrival, and show accepted/error states plus the returned occupancy. It must label all values simulated and require an explicit trip context. Do not enable real ETM ingestion until vendor samples, documentation, identity mapping evidence, security, and database migration review are available.

## Final product completion addendum — 2026-10-26

The proposed operator flow was implemented in the existing Flutter app at `lib/screens/etm/etm_simulation_screen.dart`, entered from Home in API mode. It uses the backend's simulated bus list, ordered stops, ticket/arrival simulation endpoints, and scoped occupancy refresh. All values remain explicitly simulated. The backend unit/API suite completed with 67 passing tests; the existing app's Flutter analysis passed and its 34 tests passed with `--no-test-assets`. This is mocked/unit evidence only; the backend was not connected to PostgreSQL or live ETM hardware.

