# SafarSetu API contract (prototype)

Base path: `http://localhost:8080/api`. JSON is UTF-8. List endpoints use Spring's paginated JSON envelope and accept `page` (zero-based), `size` (maximum 100), and `sort` (default stable ID sort). All rows currently returned by the development seeder are simulated.

## DTOs

Bus:

```json
{"busId":"BUS-SIM-001","fleetCode":"BUS-SIM-001","routeId":"SIM-GN-001","routeName":"SIMULATED Noida Sector 18–Knowledge Park–Pari Chowk","seatingCapacity":35,"totalPassengerCapacity":50,"dataOrigin":"SIMULATED","active":true}
```

Stop: `stopId`, `name`, `latitude`, `longitude`, `verificationStatus`, and `stopOrder` (null on `/stops`; route-specific integer on `/routes/{routeId}/stops`). The current `Stop` entity has no stop-code field; stop IDs are the stable identifiers. Coordinates are marked `APPROXIMATE` in the simulated dataset. Route: `routeId`, `name`, `dataOrigin`, `active`, `startStopId`, `endStopId`.

Occupancy:

```json
{"busId":"BUS-SIM-001","tripId":"SIM-TRIP-BUS-SIM-001-DEMO-01","routeId":"SIM-GN-001","routeName":"SIMULATED Noida Sector 18–Knowledge Park–Pari Chowk","stopId":"SECTOR_62","stopName":"Noida Sector 62","stopOrder":2,"calculatedAt":"2026-10-24T08:00:00Z","dataUpdatedAt":"2026-10-24T07:55:00Z","freshnessStatus":"SIMULATED","crowdingCategory":"LOW","onboardPassengers":5,"ticketDerivedOnboardPassengers":5,"confirmedReservedPassengers":2,"seatingCapacity":35,"totalPassengerCapacity":50,"provisionalAvailableSeats":30,"remainingPassengerCapacity":43,"calculationConvention":"AFTER_STOP_EVENTS","occupancyStatus":"CALCULATED","seatEstimateAssumption":"Route-stop estimate applies boardOrder <= queryOrder and destinationOrder > queryOrder. Ticket-derived onboard estimates and confirmed reservations are shown separately; a linked booking is excluded from reservations after its ticket event is accepted.","dataQualityWarnings":[],"dataOrigin":"SIMULATED"}
```

Occupancy immediately after a route stop is calculated with `boardOrder <= queryOrder && destinationOrder > queryOrder`; a passenger is counted at the boarding stop and no longer counted at the destination stop. Route stop orders must be contiguous from zero. Ticket timestamps do not affect this route-position estimate. `onboardPassengers` remains as a backward-compatible alias for `ticketDerivedOnboardPassengers`. Confirmed, unreleased passenger bookings on the same bus/trip/segment are reported separately as `confirmedReservedPassengers`. `remainingPassengerCapacity` is `totalPassengerCapacity` minus the unique ticket-derived and confirmed-reservation load for that segment. These are simulated records and do not prove physical boarding.

When ticket rows exist, `provisionalAvailableSeats = seatingCapacity - ticketDerivedOnboardPassengers` under a one-passenger-per-seat assumption; this legacy seat estimate does not subtract reservations. `remainingPassengerCapacity` is the separate total-passenger limit after both unique loads. Exceeding known total passenger capacity returns 409. A bus/trip with reservations but no ticket events returns an unknown ticket-derived estimate and a known reservation count; `occupancyStatus` is `CALCULATED_WITH_WARNINGS`. A bus/trip with neither ticket nor booking events returns `NO_TICKET_DATA`, unknown ticket-derived occupancy, and unknown remaining capacity. `dataUpdatedAt` is the newest selected-trip ticket event or confirmed booking creation time. `freshnessStatus` is `MISSING`, `UNKNOWN` (for example, future event timestamps), `STALE`, `FRESH`, or `SIMULATED`. By default, real location records older than 15 minutes and real ticket events older than 30 minutes are stale. Set `LOCATION_STALE_AFTER` and `OCCUPANCY_STALE_AFTER` to ISO-8601 durations to configure the cutoffs. Simulated rows always remain `SIMULATED` regardless of age. `crowdingCategory` and `onboardPassengers` continue to describe ticket-derived occupancy; reservations are separately labeled and never presented as physically onboard.

Without `stopId`, the API maps the latest bus location to its nearest route stop and calculates the same route-position estimate. It flags stale locations older than 15 minutes. If no location exists, it returns `NO_LOCATION` with unknown occupancy; stored `OccupancySnapshot` values are not used as authoritative occupancy. Ticket rows are grouped by `tripId`. If exactly one assigned trip exists, it may be inferred; if multiple trips exist, the response is unknown with `TRIP_CONTEXT_REQUIRED` unless a `tripId` is supplied. Legacy tickets with no trip ID are excluded and flagged, never folded into a known trip. Ticket ingestion retains timestamp validation and duplicate protection.

## Endpoints

| Method and path | Behavior and success | Validation/errors |
|---|---|---|
| `GET /api/buses?page=0&size=20` | Paginated bus DTOs; 200 | Page size is capped at 100 |
| `GET /api/buses/{busId}` | Bus DTO; 200 | 404 if unknown |
| `GET /api/buses/search?fromStopId=KP_II&toStopId=PARI_CHOWK` | Paginated active buses whose route has both stops with boarding before destination; 200 (empty page if no route serves both) | 400 same stops or reverse order on a shared route; 404 unknown stop |
| `GET /api/routes` | Paginated route DTOs; 200 | Page size capped at 100; 409 for an inconsistent route-stop sequence |
| `GET /api/routes/{routeId}` | Route DTO including identifier, name, source, active state, first and last stop IDs; 200 | 400 blank ID; 404 unknown route; 409 invalid/missing ordered stop sequence |
| `GET /api/routes/{routeId}/stops` | Route stop list in route order; 200 | 400 blank ID; 404 unknown route; 409 invalid route-stop sequence |
| `GET /api/stops` | Paginated candidate stops; 200 | Page size capped at 100 |
| `GET /api/buses/{busId}/occupancy` | Nearest route stop to latest location; 200, or `NO_LOCATION` with unknown occupancy if no location exists | 404 unknown bus; 409 for inconsistent route/ticket data or occupancy above known total capacity |
| `GET /api/buses/{busId}/occupancy?stopId=PARI_CHOWK&tripId=SIM-TRIP-BUS-SIM-001-DEMO-01` | Returns ticket-derived onboard estimate, confirmed reserved passengers, and remaining passenger capacity for the requested segment/trip. `onboardPassengers` remains a legacy alias. `tripId` may be inferred only when one ticket/confirmed-booking trip is unambiguous. | 400 if stop is not on the route or trip ID is blank; 404 unknown bus/stop; 409 for invalid route/ticket/booking data or combined load above known total capacity. Missing/ambiguous trip context returns unknown trip-scoped values with a warning. |
| `GET /api/buses/{busId}/location` | Latest location with origin, `stale`, and `freshnessStatus` (`FRESH`, `STALE`, or `FUTURE_TIMESTAMP`); 200 | 400 blank bus ID; 404 unknown bus or no location; 409 inconsistent bus association, missing timestamp/source, or invalid coordinates |
| `POST /api/etm/tickets` | Inserts one simulated ticket; 201 | 400 invalid fields, timestamp, or route order; 404 unknown bus/stop; 409 duplicate ticket/idempotency key, database uniqueness conflict, or resulting occupancy above known passenger capacity |

Ticket request:

```json
{"ticketId":"T-CLIENT-001","idempotencyKey":"client-event-001","busId":"BUS-SIM-001","tripId":"SIM-TRIP-BUS-SIM-001-DEMO-01","boardingStopId":"PARI_CHOWK","destinationStopId":"ALPHA_1","passengerCount":3,"boardedAt":"2026-10-12T08:00:00Z"}
```

Ticket ID and idempotency key must be nonblank and within 64/100 characters. `tripId` is required and limited to 64 characters. Passenger count must be positive. Timestamp must be present and not more than 60 seconds in the future. Both stops must be on the bus's assigned route, with boarding order lower than destination order. Repeated IDs/keys return conflict and do not add passengers a second time. Tickets accepted by this simulated ETM endpoint are stored as `SIMULATED`.

The ingestion capacity check considers only ticket rows for the same bus and `tripId`, so passenger counts from separate trips are not combined. The API has no operator authentication; use the endpoint only in a controlled local demo environment. Ingestion acquires a pessimistic write lock on the bus row while it reads existing tickets and validates the trip aggregate, so concurrent ticket submissions for the same bus serialize. Ticket/idempotency uniqueness constraints still handle duplicates; PostgreSQL lock behavior has not yet been integration-tested.

### Existing database upgrade

`db/migration/V1__ticket_trip_context.sql` safely adds a nullable `trip_id` column, assigns only the 18 known stable simulated ticket IDs to their deterministic demo trip, and adds the lookup index. It does not delete or recreate tables or other records and can be rerun. Apply it to an existing PostgreSQL database after backing it up and before relying on seeded occupancy. Other legacy rows remain unassigned; the API reports unknown trip context instead of mixing them. New ticket ingestion always requires `tripId`.

Error response shape:

```json
{"timestamp":"2026-10-12T08:00:00Z","status":400,"error":"Bad Request","message":"Request validation failed","path":"/api/etm/tickets","fieldErrors":{"passengerCount":"must be greater than 0"}}
```

Validation failures include `fieldErrors`; parameter-validation entries use a generic message and do not include raw framework exception text. Database access failures return 503 with a generic message; unexpected errors return 500. Other errors return an empty object. Server internals, exception details, SQL details, and credentials are not returned.

Example latest-location response (values are illustrative simulated coordinates from the seeded `BUS-SIM-001` route):

```json
{"busId":"BUS-SIM-001","latitude":28.6277,"longitude":77.3729,"recordedAt":"2026-10-24T08:00:00Z","dataOrigin":"SIMULATED","stale":true,"freshnessStatus":"SIMULATED"}
```

`GET /api/health` reports that the web application responds (`{"status":"UP"}`); it does not perform a PostgreSQL connectivity check. Location freshness uses the configured cutoff. Real locations are `STALE`, `UNKNOWN` for a future timestamp, or `FRESH`; simulated locations are always `SIMULATED` and retain the separate `stale` boolean to indicate age. Seeded coordinates are synthetic and are never represented as live GPS. A route-stop sequence must contain at least two unique stops with contiguous zero-based order; inconsistent sequences return 409. Page sizes are bounded to 1–100. Times are ISO-8601 instants in UTC (`Z`).

## Profiles, CORS, and deployment

The default profile is `dev`: it allows local Web origins (`localhost`/`127.0.0.1` with any port), uses Hibernate `update`, and enables insert-only simulated seeding unless `SEED_DEMO_DATA=false`. Set `SPRING_PROFILES_ACTIVE=prod` explicitly for deployment. The production profile disables seeding, forces Hibernate `validate`, and sets PostgreSQL JDBC `sslmode=verify-full`. Provide required `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`; configure a trusted database CA for the PostgreSQL JDBC driver. Pool connection and validation timeouts are bounded by configuration.

Production CORS is off by default. `CORS_ALLOWED_ORIGINS` may contain comma-separated exact HTTP(S) origins with no path or wildcard. The service has no authentication or authorization: all API paths, including ETM ticket ingestion, are publicly callable to any network client that can reach the server. Do not expose the prototype publicly until authentication, authorization, and abuse controls are implemented and reviewed. Use a private network boundary and HTTPS in the meantime. Hibernate `update` is only a local development convenience; use reviewed migrations before deployment.

## Flutter/base URL notes

Flutter has an opt-in API integration for journey search and bus details; mock mode remains the default. Search resolves stable stop IDs, then requests each matching bus's occupancy at the selected boarding stop and ETA for the destination. Per-bus occupancy failures remain distinct from `NO_TICKET_DATA` and do not remove the bus from results. The service calculates occupancy; Flutter does not merge trip ticket events or recalculate backend crowd categories. Ambiguous trips remain unknown unless a valid `tripId` is explicitly selected through the API. See `../docs/FLUTTER_BACKEND_INTEGRATION.md` for client configuration and platform limits.
Flutter's simulated trip ID is `SIM-TRIP-<busId>-DEMO-01`, matching the backend seed records and ETM validation. For bus options, `GET /api/buses/{busId}/eta?toStopId={stopId}` returns a route-based estimate or an explicit unavailable `status` such as `NO_LOCATION`, `STALE_LOCATION`, or `DESTINATION_REACHED_OR_PASSED`. Available estimates include `etaMinutes`, `estimatedRouteDistanceKm`, `dataOrigin`, `estimateType`, and the calculation assumption. The default speed is 25 km/h and route-distance factor is 1.3; configure with `ETA_AVERAGE_SPEED_KMH` and `ETA_ROUTE_DISTANCE_FACTOR`. This is not a live traffic or speed prediction. The development seed now adds recent simulated locations for BUS-SIM-011, BUS-SIM-012, and BUS-SIM-013 when demo seeding is enabled; existing location rows are never rewritten.

Use `http://localhost:8080/api` from a host browser/desktop client. Android emulator commonly reaches the host via `http://10.0.2.2:8080/api`; physical devices need the development machine's reachable LAN address and firewall access. These are development addresses only. Dev CORS permits localhost and 127.0.0.1 origins for Flutter Web; production CORS is disabled unless exact origins are configured. No platform runner directory exists in the current Flutter workspace.
