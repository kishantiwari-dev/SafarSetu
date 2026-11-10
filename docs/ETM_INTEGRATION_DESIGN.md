# SafarSetu ETM Integration Design

**Status:** Audit and proposal only. No application source, schema, database, or ETM data changed. **No live ETM provider is configured or verified.**

## Verified current state

- `ETM/` is a Microsoft Cloud Files directory reparse point (`0x9000601a`). Local enumeration returns zero entries. Cloud-only files may exist; vendor, device, protocol, exports, and event schema are unknown. No hydration was attempted.
- Current backend has `Ticket` rows with `tripId` as a nullable string, but no relational `Trip`/run entity. `Bus` points to one `Route`; `RouteStop` defines ordered stops. `BusLocation` stores coordinates/time only. There is no arrival, alighting, booking, device, or external-identifier entity.
- `DataOrigin.REAL` exists, but `TicketService` hardcodes `DataOrigin.SIMULATED` for the existing `/api/etm/tickets` endpoint. That endpoint is therefore a local simulated event endpoint, not real device integration.
- The previous `SAFARSETU_ETM_COMPLETE_AUDIT.md` is useful background, but some “no trip context” statements are stale: current `Ticket` has a nullable `trip_id`, current ingestion requires a `tripId`, and occupancy filters by bus and trip. There is still no referentially validated run model.
- No Spring Security dependency/filter or authorization was found. CORS is not authentication. Do not expose ticket ingestion publicly.
- Existing Flutter screens are passenger-facing search/details, not an operator dashboard. API mode reads occupancy/details/location; no ETM ticket POST or arrival flow exists in Flutter. The bus details screen loads on open and has retry only on an error; it has no accepted-event refresh subscription.

## Existing occupancy behavior

`OccupancyCalculator.atStop` applies `boardingOrder <= queryOrder && destinationOrder > queryOrder`. Thus a party is included at its boarding stop and excluded at its destination stop; parties travelling past an intermediate stop remain included. `TicketService` checks the pending request against all route-stop positions for one bus/trip and locks the bus row transactionally. Current results are derived from ticket rows on read; there is no authoritative mutable counter or arrival-triggered write.

This is a **ticket-event-derived route-position estimate**, not proof that passengers physically boarded. The data contract must separate sold/ticketed quantity, confirmed boardings, observed onboard count, predicted load, available capacity, and future ATM reservations. No source semantics currently establish which real ETM records represent ticket issuance versus validated boarding.

## Proposed ingestion architecture (not implemented)

1. Keep provider-specific parsing outside core domain logic. Add an adapter only after representative original exports or a vendor protocol sample and its field definitions are available.
2. Authenticate the device/service before accepting events. Preserve source system, device ID, source event ID, event timestamp/offset, received timestamp, sequence if supplied, and a privacy-reviewed payload hash/provenance record. Avoid retaining raw PII until a retention and access policy is approved.
3. Resolve source device, bus/fleet, route, stop, and trip identifiers through explicit, approved mapping records. Never fuzzy-match IDs or infer a bus from a similar name. Quarantine unknown mappings instead of updating occupancy.
4. Validate event type-specific fields and route order. Use unique `(source_system, source_event_id)` and idempotency semantics. An identical replay returns the original result; a duplicate key with different content is a conflict. Persist event and any projection update in one transaction.
5. Process out-of-order data using source sequence/watermarks if the vendor supplies them. Until source ordering semantics are known, retain an event as pending/rejected for reconciliation rather than applying a late event to current observed occupancy.
6. Calculate segment load from accepted events. For `[boardOrder, destinationOrder)`, a destination at Pari Chowk releases only that party for downstream segments; passengers with later destinations remain aboard. Enforce known total passenger capacity independently for each affected segment.
7. Treat `TICKET_ISSUED`, `BOARDING_CONFIRMED`, `ALIGHTING_CONFIRMED`, `TICKET_CANCELLED`, and `REFUNDED` as different event meanings if, and only if, the real source supports them. Ticket issuance alone must not be presented as observed boarding.
8. A confirmed arrival event can authorize processing of eligible alighting events at that stop. Do not alight passengers just because a timer elapsed, a destination was selected, or a GPS point is near a stop.
9. Expose source and freshness/status in API responses. Flutter should display returned data and refresh by request/polling; it must not keep its own authoritative count. A successful simulated workflow must remain conspicuously labeled simulated.

## Arrival and alighting prerequisites

No bus-arrival event exists. `BusLocation` is not an arrival signal; nearest-stop matching and timestamps do not prove arrival. Before processing arrivals, introduce a canonical service run linked to bus and route, define stop sequence and duplicate/backward-event rules, and establish a trusted arrival source. A per-run arrival record should be idempotent and sequence-aware. Process alighting once at an accepted arrival; preserve the original ticket/event and audit history.

## API proposal

Reuse `TicketService` validation/calculation and the existing occupancy endpoint rather than creating a second occupancy counter. Keep `POST /api/etm/tickets` explicitly simulated/legacy. After source discovery and security design, consider a separate authenticated normalized `POST /api/etm/events` adapter for ticket, boarding, alighting, cancellation/refund, and arrival event types, plus a trip-scoped arrival write/read contract. Exact route, fields, status codes, and authentication mechanism remain proposals pending source format and operator requirements. See `ETM_API_CONTRACT.md`.

## Database changes proposed for later approval

No migration is approved or applied. Likely staged migrations are listed in `ETM_DATA_MAPPING.md` and `ETM_API_CONTRACT.md`:

1. `service_runs` (canonical trip/run with bus, route, service date, schedule/status) and a nullable FK from event/ticket records; preserve legacy `trip_id` until verified backfill/compatibility is complete.
2. Explicit ETM device and external-identifier mapping tables for provider-scoped bus/route/stop/trip IDs.
3. A normalized `etm_events` ledger with source event identity, provenance, event type, timestamps, processing state, and database idempotency constraint. Raw payload retention is deferred pending privacy review.
4. Per-run stop arrivals/arrival processing state if not represented by the approved event ledger; unique/idempotent run-stop arrival and monotonic route order.
5. Separate future ATM booking/reservation and booking-event tables. Booked quantity must not be counted as observed boarding; do not conflate bookings with ETM events.

Before proposing production-ready DDL, inspect actual ETM samples, target PostgreSQL version/schema, data-retention rules, and existing database state through approved read-only access. Back up and review a migration before approval. No DB connectivity or schema was verified in this audit.

## Files that would likely change after approval

**Backend source:** `TicketRequest.java`, `Ticket.java` or new event/run/mapping/arrival entities, `DataOrigin` or richer provenance enums, corresponding repositories, `TicketService.java`, `BusService.java`/`OccupancyCalculator.java`, `BusController.java` or a dedicated ETM controller, DTOs, exception mapping, and authentication/configuration. Use an adapter to keep current simulated endpoint compatible where practical.

**Tests:** existing `TicketServiceTest`, `OccupancyCalculatorTest`, `RestApiControllerTest`, plus new parser/mapping/idempotency/arrival and PostgreSQL integration/concurrency tests.

**Flutter (only after API/security approval):** `lib/data/api_bus_repository.dart`, `lib/data/api_client.dart` if needed, and the bus-details screen for explicit refresh/loading/source state. A real ETM operator workflow/dashboard does not exist; adding one would require new screens, authorization, and product approval. Do not modify the separate `ATM/` app in this ETM phase.

**Database:** only the staged migrations above, individually reviewed and approved before application. None are run by this plan.

## Blockers and approval gate

Live ingestion must remain disabled until real sample files/protocol are accessible; provider and event semantics are documented; all external ID mappings are verified; a canonical run identity and source sequence/replay policy are agreed; authentication is selected; and PostgreSQL migration/backup/rollback plan is reviewed. After this design is accepted, implement parser + mapping in a controlled non-production environment, add mocked tests, then PostgreSQL integration/concurrency tests. Hardware connection and any schema change require separate approval.
