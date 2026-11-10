# SafarSetu + ATM — Step 2 Booking and Occupancy Integration

## Outcome

Step 2 implements the backend read-side link between passenger bookings and bus occupancy, while keeping ticket-derived onboard passengers and confirmed reservations as separate quantities. SafarSetu now displays both quantities and the remaining passenger capacity. ATM remains a separate Flutter application using the same backend URL and booking API.

No database migrations or database contents were changed. PostgreSQL and the backend were not started because the local PostgreSQL endpoint was previously verified as unreachable and no DB connection settings were present; live API and cross-app booking verification therefore remain blocked.

## Architecture retained

- SafarSetu Flutter application: `lib/`
- Passenger ATM Flutter application: `ATM/`
- Shared Spring Boot backend: `backend/`
- Shared PostgreSQL database: configured through the backend's existing datasource environment variables (`DB_URL`, `DB_USERNAME`, `DB_PASSWORD`)
- Both Flutter clients default to `http://localhost:8080/api` and support `SAFARSETU_API_BASE_URL`.

The ATM continues to submit quantity bookings through `POST /api/atm/bookings`. Its response is a booking reference/booking ID; this change does not invent or return an ETM ticket ID. No physical seat numbers or seat map were introduced.

## Implemented behavior

`BusService` now reads confirmed passenger booking rows as well as ticket events for bus occupancy. Counts are scoped to the selected trip and route segment `[boardingStopOrder, destinationStopOrder)`, so a passenger is counted on the segments after boarding and before alighting. Ticket-derived onboard passengers and confirmed reservations are exposed separately. Remaining passenger capacity is calculated from the combined unique load, so a linked booking and its ticket event cannot be double counted. Only rows with the exact `CONFIRMED_SIMULATION` status contribute as reservations; a booking linked to a ticket is excluded from the reservation subtotal even if its row status is stale.

The legacy `onboardPassengers` response field remains a ticket-derived alias for compatibility. Reservation-only occupancy is reported as a warning-level calculated result, with onboard count unknown; no ticket or booking events continue to produce `NO_TICKET_DATA`. Ticket crowding and the legacy provisional seat estimate remain ticket-derived rather than silently treating reservations as observed passengers.

## Files changed

### Backend

- `backend/src/main/java/in/safarsetu/backend/dto/OccupancyDto.java` — adds ticket-derived onboard, confirmed reservation, and remaining passenger-capacity fields, while retaining the prior constructor/field compatibility.
- `backend/src/main/java/in/safarsetu/backend/repository/PassengerBookingRepository.java` — adds bus booking lookup with the relations needed for segment evaluation.
- `backend/src/main/java/in/safarsetu/backend/repository/TicketRepository.java` — fetches linked bookings with ticket occupancy queries to avoid missing association data.
- `backend/src/main/java/in/safarsetu/backend/service/BusService.java` — combines trip/segment ticket and reservation quantities with linked-booking de-duplication and capacity reporting.
- `backend/src/test/java/in/safarsetu/backend/service/BusServiceTest.java` — covers trip/segment boundaries, reservation statuses, linked-booking de-duplication, reservation-only calculation, and over-capacity conflict.
- `backend/src/test/java/in/safarsetu/backend/controller/RestApiControllerTest.java` — checks old and new occupancy response fields.

### SafarSetu Flutter

- `lib/models/backend_data.dart` — parses new occupancy quantities and falls back to `onboardPassengers` for old responses.
- `lib/models/bus.dart` — carries confirmed reservations and remaining passenger capacity through the bus model.
- `lib/data/api_bus_repository.dart` — maps warning-level trip-scoped occupancy and clears the new values when occupancy cannot be used.
- `lib/widgets/bus_card.dart` — presents ticket-derived onboard estimate, confirmed reservations, and passenger capacity remaining as distinct values.
- `lib/screens/bus_details/bus_details_screen.dart` — presents the same separation in bus details; mock mode retains its prior display.
- `test/bus_repository_test.dart`, `test/backend_mapping_test.dart`, `test/occupancy_display_test.dart` — cover model mapping, backwards compatibility, and visible labels.

### API documentation

- `backend/API_CONTRACT.md` — documents field meanings, compatibility alias, trip/segment scope, and reservation de-duplication.
- `docs/FLUTTER_BACKEND_INTEGRATION.md` — describes the revised occupancy display contract.
- `README.md` — records the shared booking/occupancy semantics and the booking-reference distinction.

## Verification actually completed

| Area | Result | Evidence and limits |
|---|---|---|
| Backend unit/API tests | **Passed** | Maven test suite: 73 tests, 0 failures, 0 errors, 0 skipped; `BUILD SUCCESS`. Uses Mockito/MockMvc and does not connect to PostgreSQL. |
| SafarSetu Flutter tests | **Passed** | `flutter test --no-test-assets`: all tests passed (36). The no-test-assets option avoids the known OneDrive-protected generated test-assets directory. |
| ATM Flutter tests | **Passed** | `flutter test`: all tests passed (4). ATM source and API contract were not changed. |
| Flutter static analysis | **Not verified** | A bounded `flutter analyze` attempt previously produced no diagnostics and stalled beyond 60 seconds; that attempt was stopped. |
| PostgreSQL connectivity | **Blocked/unverified** | Port 5432 was not accepting a local connection, and DB settings were absent. No database was accessed or modified. |
| Running backend/API against PostgreSQL | **Not run** | Port 8080 was not listening. Health, stops, search, booking, and post-booking occupancy were not live-tested. |
| Browser end-to-end flow | **Not run** | No browser or running API/database was available for end-to-end verification. |

## Database and runtime caveats

The existing backend has the passenger booking entity/repository and booking API. Existing SQL files under `backend/db/migration/` are draft migrations; the project does not currently include a Flyway or Liquibase migration runner. The draft V2 SQL unique key `(bus_id, trip_id, stop_order)` differs from the entity key `(trip_id, stop_order)` and requires reconciliation before migration/schema use. This work did not run or alter any migration.

The root directory has no accessible Git metadata, so a Git status/diff baseline could not be reported. No existing application, ETM, or passenger-kiosk files were deleted or moved.

## Next steps

1. Identify the existing PostgreSQL service/database and configure the backend's existing `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` securely. Do not initialize a new database. Review the schema and draft migrations separately before applying anything.
2. Start the backend from `backend/` using the verified environment, then check `http://localhost:8080/api/health` and the actual stops, search, and occupancy endpoints.
3. In separate terminals, run SafarSetu from the project root and ATM from `ATM/` against the same backend URL. For example:

   ```powershell
   # SafarSetu, project root
   flutter run -d edge --dart-define=SAFARSETU_DATA_SOURCE=api --dart-define=SAFARSETU_API_BASE_URL=http://localhost:8080/api

   # ATM, ATM directory
   flutter run -d edge --dart-define=SAFARSETU_API_BASE_URL=http://localhost:8080/api
   ```

4. With a supported demo journey and data, submit a quantity booking through ATM, then refresh SafarSetu and confirm reservations and remaining capacity update on the affected segments. Also verify linked ticket ingestion does not double count.
5. Run static analysis once the local Flutter command environment is responsive. Resolve the existing schema/migration discrepancy before any schema rollout.

## Direct status

The shared booking-to-occupancy code path is implemented and its mocked/unit tests pass. The separate Flutter apps remain separate and point at the same backend contract. Live database persistence, actual API response data, browser behavior, and cross-app refresh are **not yet verified** because PostgreSQL/backend are not running and database connection settings are unavailable.
