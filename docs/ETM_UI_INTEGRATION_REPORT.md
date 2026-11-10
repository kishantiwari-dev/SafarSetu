# ETM simulation UI integration report

Date: 2026-10-26

## Workflow and navigation

The Home screen header now has an ETM simulation action. In API mode it opens a dedicated simulation screen. In mock-data mode the same entry shows instructions to restart in API mode; the passenger mock repository and existing screens remain unchanged.

The screen loads active backend buses classified `SIMULATED`, loads each bus's route stops in backend order, and allows the operator to submit a synthetic ticket event or simulated arrival for an explicit string `tripId`. The app suggests a `SIM-<busId>-<UTC-date>` trip context and allows editing it. The context is a simulation string, not a canonical service run.

Ticket validation requires a selected bus, trip identifier, boarding and destination stops in forward route order, and a positive whole passenger count. Arrival requires a bus, trip identifier, and stop; duplicate/backward sequence rules remain authoritative in the backend. Buttons are disabled during submissions/refresh, and no background retry is performed. An explicit retry after an ambiguous network timeout reuses the same ticket/idempotency key or arrival event ID.

## Exact APIs used

- `GET /api/buses?page=0&size=100` — selects only active entries whose response `dataOrigin` is `SIMULATED`.
- `GET /api/routes/{routeId}/stops` — obtains the ordered stop list; route stop orders are checked before use.
- `POST /api/etm/tickets` — JSON fields: `ticketId`, `idempotencyKey`, `busId`, `boardingStopId`, `destinationStopId`, `passengerCount`, `boardedAt` (UTC ISO-8601), and `tripId`. The UI displays the server receipt ID, `eventStatus`, and server-assigned `dataOrigin`.
- `POST /api/etm/simulated/arrivals` — JSON fields: `eventId`, `tripId`, `busId`, `stopId`, and `arrivedAt` (UTC ISO-8601). The UI displays the server receipt and labels `simulatedAlightingPassengers` as expected alighting according to `alightingMeaning`.
- `GET /api/buses/{busId}/occupancy?stopId={stopId}&tripId={tripId}` — refreshes only the affected bus, stop, and trip after accepted submissions and on manual refresh.

A ticket receipt remains visible when the subsequent occupancy refresh fails. Refresh errors are shown separately. Values are labeled SIMULATED / ticket-derived; the screen explicitly says they are not observed physical passenger counts. No time-based decrement, seat number, or seat assignment was added.

## Backend capability gap

The backend has no canonical service-run entity or run-selection endpoint. Phase 1 intentionally retained `tripId` as a string. This UI uses that existing contract for simulation and does not associate it with a real run. If a future operator workflow needs server-validated run selection, the smallest safe addition is a simulation-only `GET /api/etm/simulated/runs?busId=...` backed by an explicitly created run record; do not invent a real run or infer one from a bus. No backend changes were needed for this UI phase.

## Files changed

- `lib/data/etm_simulation_repository.dart` — typed simulation API gateway, payloads, receipt parsing, SIMULATED bus filtering, occupancy refresh.
- `lib/screens/etm/etm_simulation_screen.dart` — operator simulation screen, loading/error/success/refresh states and Home navigation target.
- `lib/screens/etm/etm_validation.dart` — trip, passenger count, and route-order validation.
- `lib/screens/home/home_screen.dart` — Home header navigation entry.
- `test/etm_simulation_repository_test.dart` — request/response contract tests for bus filtering, ordered route stops, ticket/arrival payloads, and occupancy context.
- `test/etm_simulation_screen_test.dart` — screen tests for accepted ticket receipt, refresh failure after acceptance, and backend arrival conflict display.
- `test/etm_validation_test.dart` — local validation tests.

No dependencies or backend source/schema were changed. No migration was executed; no services were started.

## Test results

Flutter/Dart formatting, analysis, and tests were not run. The bounded attempt to run `C:\Users\PC\flutter\bin\flutter.bat --version` did not return output within the tool's 30-second command window; the captured command output was empty. The Flutter executable exists at that path, but CLI reliability remains unresolved. Consequently, the newly added Flutter tests are present but unverified and no Flutter pass is claimed. Backend tests were not rerun because backend code was unchanged in this phase.

PostgreSQL was not checked or started in this phase. The new backend entity from Phase 1 expects the V2 `simulated_trip_arrivals` table while Hibernate uses schema validation. Before launching the backend against a database without that table, review and explicitly apply the approved migration through a separately authorized migration process. This phase did not apply it.

## Manual launch and verification

1. Review/apply V2 only through the approved database migration process; do not run the backend until its schema validates.
2. Start the backend using the project's approved local configuration.
3. In the project root, configure API mode and launch Flutter Web, for example:

   ```powershell
   flutter run -d edge --dart-define=SAFARSETU_DATA_SOURCE=api --dart-define=SAFARSETU_API_BASE_URL=http://localhost:8080/api
   ```

4. Open the Home header's science icon. Select an active SIMULATED bus, inspect its ordered route, submit a valid ticket, and verify the returned receipt and occupancy refresh. Then record the next route stop and confirm expected alighting plus refreshed occupancy.
5. Try a destination before boarding and a repeated/backward arrival; confirm local validation and backend error text respectively.

The backend API is currently unauthenticated and remains simulation-only. Do not expose it to untrusted networks or use synthetic identifiers as real fleet mappings.

## Final product completion addendum — 2026-10-26

The Flutter version command now completes when run with access to the installed SDK; the earlier silent hang was traced to the Codex sandbox's read-only SDK ACL preventing `flutter.bat` from opening its cache lock for writing. No ACL was changed. The ETM screen had a validator import path error and its scroll-dependent widget tests tapped controls below the viewport; both issues were corrected. Current root analysis is clean and all 34 Flutter tests pass using `flutter test --no-test-assets`. The default test command still cannot clean the pre-existing OneDrive reparse-point `build/unit_test_assets` because its ACL has an `Everyone` delete-subdirectories deny rule; the supported no-assets run avoids that directory. No project build artifacts were deleted.

