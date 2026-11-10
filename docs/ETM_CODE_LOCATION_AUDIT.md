# SafarSetu ETM Code Location and Implementation Audit

**Audit date:** 2026-10-26  
**Project root:** `C:\Users\PC\OneDrive\Desktop\safersetu`  
**Scope:** Read-only source, test, sample, migration, and documentation inspection. This audit did not execute tests, start services, run migrations, or access the database. The only file created for this request is this report.

## Direct answer

There is **no complete standalone ETM application in `ETM/`**. The locally inspectable ETM simulation is implemented in two places:

- **Spring Boot simulation API and occupancy logic:** `backend/src/main/java/in/safarsetu/backend/`
- **Operator-facing simulation workflow inside the existing passenger Flutter app:** `lib/`

`ETM/` itself is a Microsoft Cloud Files directory reparse point (reparse tag `0x9000601a`). Its local recursive listing returned no children. The contents may exist remotely, but they are not available to inspect in this checkout. `ATM/` is a separate passenger booking kiosk and is not an ETM application. `passenger_kiosk_app/` contains a planning document, not an initialized app.

The implementation is **simulation-only and partial**. It accepts synthetic ticket events, calculates ticket-derived route-segment occupancy, and accepts simulated stop-arrival events with an estimated alighting count. It does not connect to ETM hardware or parse vendor data. No real device, trip, route, or stop crosswalk is implemented.

## Relevant source tree

```text
ETM/                                           Microsoft Cloud Files reparse point; no local children listed
backend/
  src/main/java/in/safarsetu/backend/
    controller/
      BusController.java                       POST /api/etm/tickets and existing occupancy GET
      SimulatedArrivalController.java          POST /api/etm/simulated/arrivals
    dto/
      TicketRequest.java                       Validated simulated ticket request
      SimulatedArrivalRequest.java             Validated simulated arrival request
      OccupancyDto.java                        Occupancy API response
    entity/
      Ticket.java                              Persisted synthetic ticket journey / optional booking link
      SimulatedTripArrival.java                Persisted simulated arrival and expected alighting
      OccupancySnapshot.java                   Snapshot entity; not the source of calculated occupancy
    repository/
      TicketRepository.java                    Ticket lookups and trip-scoped event reads
      SimulatedTripArrivalRepository.java      Arrival event and per-trip stop lookups
      BusRepository.java                       Bus lookup with pessimistic write lock
    service/
      TicketService.java                       Ticket validation, dedupe, capacity, and optional booking link
      SimulatedArrivalService.java             Simulated arrival order and expected alighting
      OccupancyCalculator.java                 Route-interval passenger count calculation
      BusService.java                          Occupancy API orchestration and trip scoping
      RouteStopSequence.java                   Ordered route validation/helpers
    config/
      DevelopmentDataSeeder.java               Insert-only synthetic buses/routes/ticket examples
  src/test/java/in/safarsetu/backend/
    controller/RestApiControllerTest.java       MockMvc ticket/occupancy API tests
    controller/TicketValidationTest.java        Ticket DTO validation test
    service/TicketServiceTest.java              Mock-based ticket/capacity/dedupe tests
    service/SimulatedArrivalServiceTest.java    Mock-based arrival/alighting tests
    service/OccupancyCalculatorTest.java        In-memory route-interval calculation tests
  db/migration/
    V1__ticket_trip_context.sql                 Draft trip_id addition/backfill/index
    V2__simulated_trip_arrivals.sql              Draft simulated arrival table/index
    V3__service_runs.sql                         Proposed relational run model
    V4__etm_identifier_mappings.sql              Proposed provider/device mapping tables
    V5__etm_event_ledger.sql                     Proposed normalized provider event ledger
    V6__passenger_bookings.sql                   Draft kiosk booking tables and ticket link
lib/
  data/
    api_client.dart                             Shared HTTP client used by the ETM adapter
    etm_simulation_repository.dart               ETM simulation API gateway and response parsing
    api_bus_repository.dart                      Passenger API data adapter (not ETM ingestion)
  screens/etm/
    etm_simulation_screen.dart                   Existing-app ETM simulation operator screen
    etm_validation.dart                          Local trip/count/route-order validation
  screens/home/home_screen.dart                  Navigation entry for the ETM simulation screen
test/
  etm_simulation_repository_test.dart            Mock HTTP request/response contract tests
  etm_simulation_screen_test.dart                Widget tests using a fake gateway
  etm_validation_test.dart                       Local validation tests
backend/DATASET_DOCUMENTATION.md                 Synthetic seed data counts and limitations
docs/
  ETM_API_CONTRACT.md                            Documented simulated endpoints
  ETM_DATA_MAPPING.md                            Mapping gap analysis and proposed rules
  ETM_IMPLEMENTATION_REPORT.md                   Simulation implementation notes (contains older claims)
  ETM_INTEGRATION_DESIGN.md                      Proposed real-provider architecture
  ETM_MIGRATION_REVIEW.md                        Draft migration review
  ETM_TEST_REPORT.md                             Test plan/status (contains stale statements)
  ETM_UI_INTEGRATION_REPORT.md                   Flutter simulation UI notes
  examples/etm_simulation/                       Synthetic JSON examples and blank CSV template
ATM/                                             Separate passenger booking kiosk, not ETM
passenger_kiosk_app/PROJECT_PLAN.md              Future kiosk plan; not ETM source
```

## Feature-to-file map and status

| Capability | Exact project-relative files | Finding |
|---|---|---|
| ETM simulation backend | `backend/src/main/java/in/safarsetu/backend/service/TicketService.java`, `SimulatedArrivalService.java`; controllers and DTOs below | **IMPLEMENTED AND TESTED** for simulation via mocked service/API tests. Not a vendor integration. The audit did not rerun tests. |
| Ticket event submission | `backend/src/main/java/in/safarsetu/backend/controller/BusController.java` (`POST /api/etm/tickets`), `dto/TicketRequest.java`, `service/TicketService.java` | **IMPLEMENTED AND TESTED** at unit/MockMvc level. Requires ticket ID, idempotency key, bus, ordered internal stops, count, timestamp, and string trip ID. Events are forced to `SIMULATED`. Duplicate IDs/keys are rejected with conflict; exact replay does not return a prior success receipt. |
| Simulated arrival and alighting | `controller/SimulatedArrivalController.java`, `dto/SimulatedArrivalRequest.java`, `service/SimulatedArrivalService.java`, `entity/SimulatedTripArrival.java`, `repository/SimulatedTripArrivalRepository.java` | **IMPLEMENTED AND TESTED** with mocks. Arrival order/time and duplicate event/stop checks are present. Alighting is calculated from simulated ticket destinations at/before the arrival timestamp and labeled `SIMULATED_EXPECTED_ALIGHTING`; it is not a physical observation. No standalone alighting event endpoint or lifecycle is implemented. |
| Passenger occupancy calculations | `service/OccupancyCalculator.java`, `service/BusService.java`, `dto/OccupancyDto.java`, `controller/BusController.java` (`GET /api/buses/{busId}/occupancy`) | **IMPLEMENTED AND TESTED** as ticket-derived route interval logic. Passengers count at boarding and are excluded at destination (`boardingOrder <= queryOrder && destinationOrder > queryOrder`). Trip context prevents mixing separate trip strings. It is not a live sensor/headcount feed. |
| ETM-related database entities | `entity/Ticket.java`, `entity/SimulatedTripArrival.java`; related existing `entity/Bus.java`, `Stop.java`, `Route.java`, `RouteStop.java` | **IMPLEMENTED BUT NOT VERIFIED** against a live database. JPA mappings exist; annotations do not prove deployed schema. `Ticket.tripId` remains a string, not a relational run. `OccupancySnapshot` is not used as authoritative ticket calculation input. |
| ETM-related repositories | `repository/TicketRepository.java`, `repository/SimulatedTripArrivalRepository.java`, `repository/BusRepository.java` | **IMPLEMENTED BUT NOT VERIFIED** with PostgreSQL. Service tests use repository mocks. `BusRepository.findByIdForUpdate` declares the pessimistic write lock used by ingestion; its real database/concurrency behavior was not tested here. |
| REST controllers and DTOs | `controller/BusController.java`, `controller/SimulatedArrivalController.java`; `dto/TicketRequest.java`, `dto/SimulatedArrivalRequest.java`, `dto/OccupancyDto.java` | **IMPLEMENTED AND TESTED** through standalone MockMvc and validation tests, not a running server. Ticket route shares the general bus controller; there is not a second competing ticket controller. |
| Flutter ETM simulation screen | `lib/screens/etm/etm_simulation_screen.dart`, `lib/screens/etm/etm_validation.dart`, `lib/screens/home/home_screen.dart` | **IMPLEMENTED BUT NOT VERIFIED** for the latest source state. Widget/validation test source exists and prior reports record Flutter tests, but the latest optional booking-reference UI addition was not rerun. It is inside the existing Flutter app and requires API mode for backend operation. |
| Flutter ETM API repository/client | `lib/data/etm_simulation_repository.dart`, `lib/data/api_client.dart` | **IMPLEMENTED BUT NOT VERIFIED** for the latest source state. Mock HTTP contract tests exist and were previously reported passing; this audit did not rerun them. The adapter loads active `SIMULATED` buses and ordered internal route stops, posts simulated events, and fetches trip/stop-scoped occupancy. No live HTTP session was verified. |
| ETM tests | `backend/src/test/java/in/safarsetu/backend/service/TicketServiceTest.java`, `SimulatedArrivalServiceTest.java`, `OccupancyCalculatorTest.java`, `controller/RestApiControllerTest.java`, `controller/TicketValidationTest.java`; Flutter tests under `test/` listed above | **IMPLEMENTED AND TESTED** only for the mocked/unit/MockMvc behaviors represented in the test source. No PostgreSQL-backed integration/concurrency, real vendor, device, or live browser test exists. The current audit did not execute tests. |
| ETM migration drafts | `backend/db/migration/V1__ticket_trip_context.sql` through `V6__passenger_bookings.sql` | **DOCUMENTATION / DRAFT ONLY**; no Flyway/Liquibase dependency or migration runner was found in `backend/pom.xml`. No migration was executed. V3–V5 propose run/provider/device/mapping/event-ledger tables without corresponding JPA runtime entities/repositories. V6 is passenger booking, not ETM. |
| ETM docs and sample data | `docs/ETM_*.md`, `docs/examples/etm_simulation/{README.md,simulated_ticket_event.json,simulated_arrival_event.json,mapping_template.csv}`, `backend/DATASET_DOCUMENTATION.md`, `backend/src/main/java/in/safarsetu/backend/config/DevelopmentDataSeeder.java` | **DOCUMENTATION ONLY** for provider mapping and vendor integration. The JSON examples and seeded ticket rows are synthetic. The CSV is a header-only template, not a verified mapping dataset. |
| Real vendor/device integration | No implementation found under `backend/`, `lib/`, or locally enumerable `ETM/` | **BLOCKED BY MISSING VENDOR DATA**. No vendor parser, upload/import flow, device transport, provider/device entity, authenticated source identity, external-ID resolver, or production event adapter exists. |

## What the source actually does

### Ticket ingestion

`BusController` maps `POST /api/etm/tickets` to `TicketService.ingest`. The service rejects duplicate ticket IDs/idempotency keys, locks the bus row, requires a `SIMULATED` bus, validates that stops exist on the bus route and are in order, checks timestamp and trip string, then validates per-segment capacity. It persists a `Ticket` marked `SIMULATED`. Its interval is interpreted by the occupancy calculator as a ticketed journey from boarding to destination.

An optional `bookingReference` links a matching kiosk booking (`PassengerBooking`) to this simulated ticket. It is not evidence that an actual ETM device validated a passenger. A matching link marks the booking `BOARDING_RECORDED_SIMULATION`; it does not introduce a real boarding event or alighting lifecycle.

### Arrival and occupancy

`POST /api/etm/simulated/arrivals` records a `SimulatedTripArrival`; it accepts one event ID, string trip ID, bus ID, internal stop ID, and timestamp. It rejects duplicate event IDs and repeated/backward route stops. It derives expected alighting from simulated ticket destination stops and returns current trip-scoped occupancy from `BusService`.

The arrival row is persisted by a Spring Data repository in source, but no database test or live DB verification was performed. A ticket's destination represents the end of its modeled interval; it does not establish an observed alighting event. There is no independent actual alighting report endpoint.

### Application boundaries

The ETM screen at `lib/screens/etm/etm_simulation_screen.dart` is navigated to from `lib/screens/home/home_screen.dart` and calls the backend through `EtmSimulationRepository`. It is part of the existing passenger Flutter app rather than a standalone operator product. `ATM/` is a distinct passenger booking kiosk, while `passenger_kiosk_app/` only has `PROJECT_PLAN.md`.

## `ETM/` folder finding

PowerShell metadata showed `ETM` has `Directory, ReparsePoint` attributes. `fsutil reparsepoint query ETM` reported Microsoft Cloud Files tag `0x9000601a`. A local recursive listing produced no child entries. This means no ETM source, documentation, or sample file could be inspected from that path locally. It does **not** establish that the cloud copy is empty. No hydration or modification was attempted.

## Missing capabilities and limitations

| Capability | Status | Evidence / limitation |
|---|---|---|
| Real ETM device connection/protocol | **BLOCKED BY MISSING VENDOR DATA** | No vendor, model, protocol, credentials, or sample data locally available. |
| Vendor file/API parsing | **NOT IMPLEMENTED**; blocked until format supplied | No parsers, ETL/import code, or vendor client found. |
| Device-to-bus identity mapping | **NOT IMPLEMENTED**; blocked until verified inventory supplied | V4 contains a proposed SQL table only; no entity/repository/resolver or verified mapping rows. |
| Canonical trip/run mapping | **NOT IMPLEMENTED** for runtime | `tripId` is a caller-supplied string. `service_runs` appears in V3 draft only; no service-run entity or assignment validation found. |
| Vendor route/stop mapping | **NOT IMPLEMENTED**; blocked until official crosswalk supplied | Simulation validates internal route/stop IDs only. V4 is a schema proposal, not an active mapping implementation. |
| Ticket event ingestion | **IMPLEMENTED AND TESTED** for simulated requests | Mock/unit and MockMvc source tests cover validation/deduplication/capacity. No vendor source accepted or live DB-tested. |
| Actual boarding event handling | **NOT IMPLEMENTED** | `TicketRequest.boardedAt` is ingested as a simulated ticket journey; no device-confirmed boarding event type/provenance exists. |
| Actual alighting event handling | **NOT IMPLEMENTED** | Expected alighting is derived from destination stop; no alighting input endpoint, event state machine, correction, or replay ledger. |
| Simulated arrival processing | **IMPLEMENTED AND TESTED** | Mock service tests cover accepted arrival, duplicate event, backward/repeated route progression, off-route stop, and derived expected alighting. No physical arrival detection. |
| Duplicate protection | **IMPLEMENTED AND TESTED**, limited semantics | Ticket ID and idempotency key are unique/rejected on repeat; arrival event ID and trip-stop are unique/rejected. This is conflict-on-duplicate protection, not successful idempotent replay returning the original receipt. V5's provider-scoped event ledger is not implemented. |
| Database persistence | **IMPLEMENTED BUT NOT VERIFIED** | JPA entities and repositories exist; V1/V2 and V6 drafts include related columns/tables. No migrations were run; no DB integration tests verified schema, rollback, or concurrency. |
| Authentication/authorization | **NOT IMPLEMENTED** | No Spring Security/OAuth dependency or ETM device authentication mechanism was found. The API contract warns endpoints are unauthenticated. |
| End-to-end SafarSetu integration | **IMPLEMENTED BUT NOT VERIFIED** for simulation | Flutter adapter calls the Spring API contract and has mocked HTTP/widget tests. No live backend/database/browser/device end-to-end workflow was performed in this audit. |

## Duplicate, misplaced, and stale material

- There is one `POST /api/etm/tickets` mapping, in `backend/src/main/java/in/safarsetu/backend/controller/BusController.java`; no duplicate ETM ticket controller was found.
- Simulated arrival has one controller, service, entity, and repository. `PassengerBooking` and `PassengerBookingRepository` are separate passenger kiosk functionality, not ETM device integration.
- `backend/db/migration/V4__etm_identifier_mappings.sql` and `V5__etm_event_ledger.sql` are SQL proposals only. No matching provider/device/mapping/event-ledger JPA entities or runtime repositories were found.
- The V2 SQL declares arrival uniqueness on `(bus_id, trip_id, stop_order)`, while `SimulatedTripArrival` declares JPA uniqueness on `(trip_id, stop_order)` without `bus_id`. This schema-definition mismatch needs reconciliation before any migration or schema update is considered.
- `docs/ETM_TEST_REPORT.md` has older sections claiming arrivals and the Flutter ETM submit flow were not implemented; later addenda and current source show they now exist. Treat those older statements as stale. Other ETM reports also have earlier test counts or describe earlier phases. Current source and test files should be used to resolve capability, while any test result should be treated as historical unless rerun.
- `docs/examples/etm_simulation/mapping_template.csv` is header-only. The JSON event examples and Java development seeder contain synthetic identifiers and are not vendor sample data.
- No duplicate or standalone ETM application source was found in `ETM/`, `ATM/`, or `passenger_kiosk_app/`. The empty local listing of the cloud placeholder limits conclusions about remote files.

## Is ETM a separate project?

It is a **combination of features in the existing application projects**, not a separate ETM application:

1. Backend simulation: existing Spring Boot project under `backend/`.
2. Simulation UI: existing root Flutter project under `lib/`.
3. Passenger kiosk: separate Flutter project under `ATM/`, not an ETM operator app.
4. `ETM/`: unavailable cloud-files placeholder locally, not an inspectable source project.
5. `passenger_kiosk_app/`: project planning only.

Therefore the full real-world ETM integration is **not complete**. Only the simulation workflow is implemented.

## Exact next steps to complete a real ETM integration

1. Make representative ETM files available locally without replacing the cloud originals; obtain vendor/protocol documentation, device inventory, and sanitized examples for every export/event type.
2. Confirm the semantics of each record: ticket sale versus validated boarding, destination versus observed alighting, cancellations/refunds, clock/time zone, ordering, offline replay, corrections, and passenger-count meaning.
3. Establish authoritative crosswalks for device, bus/fleet, route, stop, and service run. Do not use demo IDs, fuzzy names, or inferred GPS proximity as production mappings.
4. Define a canonical service-run model and provider-scoped event identity/provenance. Design duplicate and conflicting-replay behavior, quarantine for unknown mappings, and secure device authentication before ingestion is exposed.
5. Reconcile the V2 uniqueness mismatch and review V1–V6 against a known schema. Select a migration mechanism, test on a disposable database, verify backup/rollback, and obtain explicit approval before applying anything to the target database.
6. Implement vendor parsers/adapters and normalized boarding/alighting/arrival events with auditable source IDs, timestamps, sequence/replay controls, and privacy/retention rules. Keep simulated and real-origin data distinct.
7. Add PostgreSQL-backed persistence, migration, rollback, and concurrent-capacity tests; then run live API and Flutter end-to-end checks in a non-production environment with approved data.
8. Add authorization, device enrollment/revocation, request limits, monitoring, and operational recovery before any production use.

**Audit conclusion:** the code that exists is located in `backend/` and `lib/` and is simulation-only. `ETM/` did not expose local files. No complete standalone ETM application or verified real vendor integration exists in the inspected source.
