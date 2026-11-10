# SafarSetu Passenger Kiosk — Project Plan (Phase 1)

**Status:** Planning and inspection document. Application source has not yet been generated because the installed Flutter CLI hangs during bootstrap in this environment. No implementation or booking behavior is included in this phase.

## Purpose and scope

Build a separate Flutter passenger kiosk called `safarsetu_passenger_kiosk` for quantity-based bus tickets. Passengers will choose boarding and destination stops, select a travel date and a bus timing, view matching buses and segment capacity, choose a passenger quantity, confirm a simulated purchase, receive a ticket receipt, and follow ticket status through alighting. This is a future proposal; this phase only prepares the project location and integration plan.

No individual seats, seat map, seat numbers, or seat selection are in scope. The existing SafarSetu Spring Boot service and PostgreSQL database remain the intended backend and data store. Do not add another backend/database or treat the existing Flutter mock repository as production data.

## Evidence labels

- **Verified source fact:** directly checked in the current checkout's backend controllers, DTOs, seeder, application configuration, Flutter repository, or API contract.
- **Unverified live state:** requires a running backend/database or external ETM/operator source; not established by source inspection.
- **Proposal:** future product or engineering design, not an implemented capability.

## Existing backend endpoints that may be reused

Base URL documented by the backend: `http://localhost:8080/api`.

| Endpoint | Verified capability | Kiosk use/limit |
|---|---|---|
| `GET /api/health` | Returns `{ "status": "UP" }`; controller does not check PostgreSQL readiness | Process liveness only; not a DB-ready signal |
| `GET /api/stops` | Paginated `StopDto` with stable `stopId`, name, coordinates, verification status | Boarding/destination choices; data is simulated/approximate in seeded data |
| `GET /api/routes` | Paginated route list | Route context and route discovery |
| `GET /api/routes/{routeId}` | Route detail | Route display |
| `GET /api/routes/{routeId}/stops` | Ordered route stop list | Validate journey order and determine segment |
| `GET /api/buses` | Paginated bus records | Bus listing, not departure/timetable search |
| `GET /api/buses/search?fromStopId=…&toStopId=…` | Active buses on routes with the selected stops in boarding-before-destination order | Matching bus candidates; no date/time availability is represented |
| `GET /api/buses/{busId}` | Bus details and capacities | Selected bus details |
| `GET /api/buses/{busId}/occupancy?stopId=…&tripId=…` | Ticket-derived occupancy estimate at a route stop; trip context matters | Can inform a segment capacity estimate, but is simulated/estimated and not a booking hold |
| `GET /api/buses/{busId}/location` | Latest recorded location or error if unavailable | Optional tracking context; seeded values are simulated and can be stale |
| `POST /api/etm/tickets` | Accepts simulated ticket event: `ticketId`, `idempotencyKey`, `busId`, `boardingStopId`, `destinationStopId`, positive `passengerCount`, `boardedAt`, required `tripId`; duplicate and capacity validations are described | **Not a passenger booking endpoint.** It records a boarding/ticket event and returns an ingestion receipt; no reservation, fare, payment, expiry, or lifecycle exists. Do not call from kiosk in Phase 1. |

**Verification note:** endpoint methods and payload types were confirmed in the current controller/DTO source and API contract. No live HTTP requests were made in this phase. Contract examples are illustrative; API responses and DB connectivity were not live-verified.

## Existing bus, route, stop, and data sources

- **Verified source fact:** `backend/src/main/java/in/safarsetu/backend/config/DevelopmentDataSeeder.java` defines nine simulated routes (`SIM-GN-001` through `SIM-GN-009`), 22 approximate stops, 13 simulated buses, synthetic trip-scoped ticket events, locations, and occupancy snapshots. Stable `BUS-SIM-*` IDs and stop IDs are internal demo identifiers, not operator-verified identifiers.
- **Verified source fact:** `backend/DATASET_DOCUMENTATION.md` documents the 22 stops, 9 routes, 52 route-stop links, 13 buses, 23 ticket events, 19 location rows, and 13 snapshots as synthetic development data. Route/timetable, fare, and service availability are not established by those fixtures.
- **Verified source fact:** the existing Flutter app's `createBusRepository()` defaults `SAFARSETU_DATA_SOURCE` to `mock`; its API repository uses the backend endpoints for read-only search/details/occupancy/location. Mock results are not proof of live DB data.
- **Unverified live state:** PostgreSQL availability, current DB rows, schema state, and backend health were not checked through live connections in this phase. The previous audit found port 5432 unavailable, but that is historical and should be rechecked before integration.

## Planned passenger screens

1. **Welcome / kiosk start:** prominent “Start” and basic language/accessibility affordances.
2. **Journey selection:** boarding and destination stop search from backend stop IDs; prevent same-stop selection.
3. **Travel date and timing:** date picker and available departures once an authoritative schedule API exists. Until then, clearly labeled demo data only; do not invent schedules.
4. **Bus results:** route/bus identity, departure time when sourced, journey context, capacity freshness, and segment occupancy estimate with unknown/stale states.
5. **Passenger quantity:** quantity controls bounded by server-confirmed remaining segment capacity; explicitly quantity-based, without seat inventory.
6. **Review and simulated purchase:** journey, bus/run, passenger count, fare only if backend supplies one, and clear simulation labeling. Disabled until booking API exists.
7. **Ticket receipt:** backend-issued ticket/booking ID, trip and stop details, passenger count, timestamp, and status.
8. **Ticket status:** booked/issued, boarded, in transit, alighted, cancelled/expired/refunded as supported by backend event data; never infer confirmed alighting from route order alone.
9. **Help / kiosk reset:** clear local passenger data and return to start after a safe inactivity interval, subject to privacy requirements.

## Proposed Flutter structure

- `lib/app/`: app root, router, theme, kiosk session timeout.
- `lib/core/config/`: environment-specific API base URL and build mode.
- `lib/core/network/`: HTTP client, JSON/error parsing, request timeout, correlation/idempotency handling.
- `lib/features/journey/`: stop selection, date/time and route search models/screens.
- `lib/features/buses/`: results, bus/run details, segment capacity presentation.
- `lib/features/booking/`: review, quantity, booking submission, receipt/status models and screens.
- `lib/features/tickets/`: ticket status and lifecycle timeline.
- `lib/data/`: typed API services/repositories; production kiosk should use explicit backend mode and must not silently fall back to mock data.
- `test/`: unit/widget tests for journey validation, quantity bounds, API parsing, and lifecycle rendering; later API integration tests against a disposable PostgreSQL instance.

Keep user interface state separate from transport models. Represent `unknown`, stale, and simulated occupancy explicitly rather than showing unknown capacity as zero or implying availability.

## Missing backend capabilities for the intended workflow

The current backend does not define a first-class scheduled trip/run, passenger booking/reservation, fare/payment, or booking status lifecycle. The existing ETM ticket endpoint is an ingestion mechanism, not a booking endpoint.

Proposed APIs/domain work before enabling purchase:

- `GET /api/trips` (or equivalent): dated service runs with bus, route, stops, scheduled/estimated departure/arrival, service status, and schedule provenance.
- `GET /api/trips/{tripId}/availability?fromStopId=…&toStopId=…`: authoritative reservable passenger capacity for that segment and freshness.
- `POST /api/bookings`: authenticated or kiosk-authorized, idempotent quantity booking tied to a specific trip and leg, with server validation and atomic capacity reservation. Return server booking/ticket ID and lifecycle status.
- `GET /api/bookings/{bookingId}`: safe ticket details and lifecycle status.
- `POST /api/bookings/{bookingId}/cancel` (policy permitting): cancellation/release/refund behavior.
- Operator/ETM event ingestion for boarding and alighting, mapped to trip, bus, stop, and booking/ticket IDs, with authentication, idempotency, audit trail, and event provenance.
- A DB readiness/health signal distinct from current liveness-only `/api/health`.
- Authentication/authorization, kiosk session protections, fare and payment contracts if payment is required, data retention and operational audit policies.

## Proposed booking and ticket lifecycle

Proposal: `SEARCHED → HELD (short expiry) → CONFIRMED/ISSUED → BOARDED → ALIGHTED`, with terminal/side paths `EXPIRED`, `CANCELLED`, `REFUND_PENDING`, `REFUNDED`, and `FAILED`. A server-generated booking ID and idempotency key must prevent duplicate sales on retries. Booking confirmation must reserve capacity in a DB transaction scoped to the exact trip and segment. Clarify whether payment is in-scope before defining when a hold is confirmed.

Use a run/trip instance, not only a route or bus ID: the same bus can operate multiple runs, and capacity resets/reconciliation must be scoped to one run. Preserve the ETM's original event IDs and source timestamps and map them to the canonical trip, stop, and booking/ticket records.

## Releasing passenger counts at destination

For a quantity-based system, an issued/boarded booking contributes its passenger count only to route segments from boarding stop up to, but excluding, the destination stop. When validated alighting is recorded at the destination, mark the booking's journey complete and decrement/release its onboard count for downstream segments. Keep the original booking and event history for audit; do not delete tickets or permanently reduce the run's sold count. If an alighting event is missing, do not automatically claim the passenger alighted: use an explicit unknown/overdue state and an operations reconciliation rule. Capacity must be checked per segment so passengers alighting free capacity for later segments while passengers still onboard remain counted. This logic must be transactional and idempotent against duplicate ETM events.

## Dependencies and unresolved questions

**Known dependencies in existing app/backend:** Flutter `http` client is already used; backend uses Spring Data/JPA and PostgreSQL configuration. The kiosk can use Flutter's standard Material widgets and the existing REST API; no second service is needed.

**Unresolved before integration:**

- Is the cloud `ETM/` folder hydrated and what vendor/file format/device IDs does it contain?
- What authoritative scheduled service data, fares, operator, real bus IDs, route/stop codes, and trip/run identifiers are available?
- Which database/service/schema is intended, and what are the existing data/backup policies?
- How is `tripId` created and assigned to buses and ETM ticket rows in actual operations?
- Are ticket counts confirmed boarding, ticket sale, or another event? What does a cancellation/refund do to capacity?
- How are alighting events captured and corrected if missing or out of sequence?
- Is payment required, which payment boundary is used, and what receipt/legal requirements apply?
- What privacy rules apply to passenger identity, ticket PII, kiosk session cleanup, and retention?
- How should kiosk authorization work when passenger login is absent?
- Is “available passenger capacity” based on total passenger capacity, seats, reservations, ETM onboard count, or a combination? Current API separates seat estimate from total passenger capacity and notes the seat estimate is provisional.

## Implementation phases

1. **Phase 1 — setup and inspection (current):** create separate project location, record verified API/data facts and gaps; no booking code.
2. **Phase 2 — kiosk shell:** initialize Flutter app, navigation, theme, responsive kiosk layout, session timeout and accessibility; no purchase integration.
3. **Phase 3 — read-only backend journey flow:** stop selection, route search, bus details, clear simulated/stale capacity display; explicit API mode and error states.
4. **Phase 4 — trip and availability backend:** design scheduled runs and segment-capacity API, schema migration plan, integration tests and source-of-truth rules.
5. **Phase 5 — booking backend:** idempotent booking, transactional capacity hold/confirmation, lifecycle, authorization, cancellation policy, and concurrency tests.
6. **Phase 6 — kiosk purchase/receipt:** connect UI to booking API and issue server-backed tickets; test retry, duplicate submissions, and failure recovery.
7. **Phase 7 — ETM reconciliation:** map real ETM IDs/events, authenticated ingestion, boarding/alighting lifecycle updates, replay handling, and operational dashboards.
8. **Phase 8 — operational readiness:** DB readiness, monitoring, security review, backup/recovery, privacy, kiosk deployment, and end-to-end testing against a non-production environment.

## Phase 1 setup status

The target folder did not exist at inspection time; it now contains this plan. Flutter is installed at `C:\Users\PC\flutter\bin\flutter.bat` with Dart 3.13.2 available. However, `flutter --version` and `flutter create --no-pub --project-name safarsetu_passenger_kiosk passenger_kiosk_app --verbose` both remained silent and did not return within 30 seconds. The `flutter.bat.lock` file was not held when checked. I stopped only those two commands. The Flutter app scaffold and platform runner directories therefore remain uninitialized; no existing files were overwritten.

After the Flutter CLI bootstrap issue is resolved, initialize from this folder with:

```powershell
Set-Location 'C:\Users\PC\OneDrive\Desktop\safersetu\passenger_kiosk_app'
flutter create --no-pub --project-name safarsetu_passenger_kiosk .
```

Then validate dependencies and launch the web kiosk in Microsoft Edge with:

```powershell
Set-Location 'C:\Users\PC\OneDrive\Desktop\safersetu\passenger_kiosk_app'
flutter pub get
flutter run -d edge
```

Do not enable ticket purchase until the booking and trip capabilities above exist and are verified.
