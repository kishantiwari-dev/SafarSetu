# SafarSetu ETM API Contract — Current and Proposed

**Status:** Current endpoints below are verified in source/documentation. Proposed live event/arrival APIs are not implemented and must be revised against real ETM samples and operator security requirements.

## Existing endpoints

Base path: `/api`. Current API has no authentication/authorization. Keep it on a controlled local/private network; CORS is not an access-control boundary.

| Method/path | Current behavior | ETM relevance |
|---|---|---|
| `GET /api/health` | Returns application liveness `{ "status":"UP" }`; no PostgreSQL readiness check | Not event/DB readiness |
| `GET /api/stops` | Paginated internal stop IDs/names | Candidate mapping references; IDs have no vendor code field |
| `GET /api/routes`, `GET /api/routes/{routeId}`, `GET /api/routes/{routeId}/stops` | Route metadata and ordered route stops | Provides internal route sequence |
| `GET /api/buses`, `GET /api/buses/{busId}`, `GET /api/buses/search` | Bus/fleet metadata and matching route buses | Demo IDs are not verified fleet IDs |
| `GET /api/buses/{busId}/location` | Latest stored coordinate point, source/freshness | Location is not a confirmed arrival event |
| `GET /api/buses/{busId}/occupancy?stopId=…&tripId=…` | Ticket-derived occupancy by route order, scoped to string trip ID | Reuse/extend as read projection; not an arrival write or booking availability hold |
| `POST /api/etm/tickets` | Stores a simulated passenger interval; returns 201 receipt | Current controlled demo endpoint only; not connected to ETM hardware |

### Current simulated ticket request

```json
{
  "ticketId": "client-ticket-001",
  "idempotencyKey": "client-event-001",
  "busId": "BUS-SIM-001",
  "boardingStopId": "PARI_CHOWK",
  "destinationStopId": "ALPHA_1",
  "passengerCount": 3,
  "boardedAt": "2026-10-12T08:00:00Z",
  "tripId": "SIM-TRIP-BUS-SIM-001-DEMO-01",
  "bookingReference": "ATM-EXAMPLE-001"
}
```

`bookingReference` is optional. When supplied, the service requires an existing `CONFIRMED_SIMULATION` booking with an exact match for bus, trip, boarding stop, destination stop, and passenger count. It links the ticket record, changes the reservation status to `BOARDING_RECORDED_SIMULATION`, and returns that booking reference/status. The confirmed reservation is then excluded from reserved-capacity totals while its ticket journey is counted. This transition is a simulated ETM ticket event, not independently verified physical boarding. An unlinked ticket does not release a reservation.

Current fields are verified in `TicketRequest`. Validation requires nonblank ticket/idempotency/bus/stops/trip, IDs within configured lengths, positive count, parseable `Instant`, timestamp no more than 60 seconds in the future, known bus/stops, stops on bus route with boarding order before destination, no duplicate ticket ID/idempotency key, and capacity within every affected route-stop segment for that bus/trip. Unknown bus/stop is 404; invalid request/route ordering is 400; route/capacity/data conflicts are 409. The service uses `@Transactional` and locks the bus row through `BusRepository.findByIdForUpdate`; actual PostgreSQL lock behavior is unverified. The service sets `DataOrigin.SIMULATED` regardless of request. `tripId` is a string, not a verified FK.

The current endpoint has no device/source event ID, source event type, arrival event, cancellation/refund, sequence/watermark, timezone field beyond ISO instant offset, real-source provenance, or authentication. It does not establish that `boardedAt` means physical boarding. Duplicate checks are against ticket ID and idempotency key; replay and out-of-order source event semantics are not modeled.

## Proposed live-event contract (not implemented)

Do not finalize a vendor-facing schema until actual source files/protocol are available. Proposed normalized envelope for a protected service-to-service adapter:

```json
{
  "sourceSystem": "<verified provider namespace>",
  "sourceDeviceId": "<provider device ID>",
  "sourceEventId": "<stable provider event ID>",
  "eventType": "<verified event type>",
  "externalBusId": "<provider bus ID>",
  "externalTripId": "<provider run ID>",
  "eventTime": "<ISO-8601 instant with known offset>",
  "eventSequence": "<only if source provides one>",
  "externalRouteId": "<if source provides it>",
  "boardingStopCode": "<for ticket/boarding events if provided>",
  "destinationStopCode": "<if the event source provides a destination>",
  "passengerCount": 1
}
```

This is a **proposal**, not a claim about ETM fields. Required fields vary by verified event type. Do not reject a legitimate vendor event solely because a field the vendor never sends is absent; instead require a trusted mapping or explicit policy for that event type. Do not fabricate IDs or infer missing destinations.

Proposed processing: authenticate caller/device; validate schema and timestamp; resolve all provided source identifiers through approved mappings; resolve a canonical service run; validate route order; enforce source-event uniqueness and payload-hash conflict detection; persist ledger/event result and any derived state in one transaction; acknowledge exact replays idempotently; quarantine unknown mappings or unresolved order; log correlation/event IDs without credentials or passenger PII.

Proposed response carries `sourceEventId`, canonical `eventId`, `tripId`, status (`ACCEPTED`, `DUPLICATE`, `PENDING_MAPPING`, `REJECTED`), reason code where applicable, `dataOrigin`, and any updated occupancy projection. Exact HTTP status policy and response DTO require approval.

## Proposed arrival API (not implemented)

Only after a relational run and trusted arrival signal exist, consider an authenticated idempotent endpoint such as `POST /api/trips/{tripId}/arrivals` with mapped stop ID, source event identity, event timestamp, sequence if supplied, and source provenance. It must verify bus/run/route/stop association, reject backward arrival order, treat an identical duplicate as idempotent, reject same event key with conflicting content, process eligible alighting exactly once, and return event status plus occupancy by segment. A location point or passenger-selected destination is insufficient to mark arrival/alighting.

The current `GET /api/buses/{busId}/occupancy` should remain the read projection and be expanded only after semantics are defined to expose ticketed quantity, observed-onboard count, predicted load, booked quantity, capacity, freshness, and provenance separately. Never return one ambiguous counter for those concepts.

## Proposed error codes (not implemented)

- `400 INVALID_EVENT`: malformed envelope, impossible timestamp/count, or invalid route order.
- `401/403 UNAUTHENTICATED/UNAUTHORIZED`: missing/invalid device or service authorization.
- `404 UNKNOWN_CANONICAL_ENTITY`: canonical reference cannot be found after mapping.
- `409 DUPLICATE_CONFLICT`, `OUT_OF_ORDER_EVENT`, `CAPACITY_CONFLICT`: duplicate key with different content, invalid run sequence, or segment capacity conflict.
- `422 UNMAPPED_EXTERNAL_ID`, `TRIP_CONTEXT_REQUIRED`, `UNSUPPORTED_EVENT_TYPE`: requires mapping/operational reconciliation rather than guesswork.
- `503 DATABASE_UNAVAILABLE`: retain existing generic safe database error response.

No new endpoint, auth policy, or status-code change has been implemented. Review with actual ETM vendor/operator and the backend owner before building the live contract.

## Phase 1 simulation-only arrival addendum (2026-10-26)

The following endpoint is implemented separately from any vendor-facing ingestion:

- `POST /api/etm/simulated/arrivals` — accepts `{eventId, tripId, busId, stopId, arrivedAt}` and returns 201 with `eventStatus: ACCEPTED`, `dataOrigin: SIMULATED`, `alightingMeaning: SIMULATED_EXPECTED_ALIGHTING`, the derived expected alighting count, and the existing occupancy projection for that bus/trip/stop.

The backend rejects duplicate event IDs, duplicate trip-stop arrivals, backwards stop progression/timestamps, off-route stops, and non-SIMULATED buses. The alighting count is derived from simulated ticket journeys whose destination matches the stop; it does not establish physical alighting. No vendor payload format or external ID mapping is implemented. The endpoint follows the existing unauthenticated API pattern and is for local simulation only.

The existing `POST /api/etm/tickets` receipt now also includes `eventStatus: ACCEPTED`; `dataOrigin` remains server-assigned as `SIMULATED`. The simulated ticket endpoint rejects buses not classified `SIMULATED`.

## Passenger ATM booking simulation addendum (2026-10-26)

`POST /api/atm/bookings` is a separate passenger reservation endpoint; it is not an ETM ticket-event endpoint. The request fields are:

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

The only accepted synthetic trip context is `SIM-TRIP-{busId}-DEMO-01`. The endpoint returns HTTP 201 with `bookingReference`, `bookingStatus: CONFIRMED_SIMULATION`, `dataOrigin: SIMULATED`, and `boardingStatus: NOT_BOARDING_EVIDENCE`. A repeated same-key/same-payload request returns the original receipt; a changed payload with that key conflicts. The transaction locks the bus row and checks capacity at each route order against both ticket journeys and confirmed same-trip bookings using `[boardingOrder, destinationOrder)`. Booking reservations do not become ticket-derived or observed occupancy. This simulation has no schedule, fare, payment, cancellation, expiry, or authentication. V6 remains an unexecuted draft, and no PostgreSQL-backed request has been verified.
