# SafarSetu ETM Data and Identifier Mapping

**Status:** Source audit. Actual ETM mapping is unresolved because local source files are unavailable. No ETM file was opened, hydrated, transformed, or modified.

## ETM folder finding

`C:\Users\PC\OneDrive\Desktop\safersetu\ETM` is a directory reparse point with Microsoft Cloud Files tag `0x9000601a`. Local recursive enumeration returned no child entries. The folder may contain cloud-only files; this does not prove the remote folder is empty. No vendor, device, file format, schema, export date, encoding, or event sample can be identified from this checkout. The user must make representative original files locally available before a parser or live identifier crosswalk can be designed.

## Existing SafarSetu model (verified source)

| SafarSetu value | Existing definition | What it does and does not prove |
|---|---|---|
| `Bus.id` / `Bus.fleetCode` | `buses` table, current fixture IDs `BUS-SIM-*`; seeder sets fleet code equal to bus ID | Stable demo identifiers only. No real fleet mapping is verified. |
| `Route.id` | `routes` entity, fixtures `SIM-GN-001` … `SIM-GN-009` | Simulated corridors, not official operator route IDs. |
| `Stop.id` | `stops` entity; route order is in `route_stops` | API uses stable internal IDs; current `Stop` has no separate source/vendor stop-code field. Seed coordinates are `APPROXIMATE`. |
| `Ticket.id` | `tickets.id`, unique primary key | Current simulated ticket identifier; no ETM source namespace/device linkage. |
| `Ticket.tripId` | Nullable string `trip_id`, max 64 chars; required by current simulated ingestion DTO | Not a foreign key; no `Trip`/service-run entity validates existence, service date, route, or bus assignment. |
| `Ticket.boardingStop` / `destinationStop` | FKs to canonical stops; validated against bus route and order | Current code checks both stops on the assigned bus route and boarding before destination. |
| `Ticket.boardedAt` | UTC `Instant` persisted as `boarded_at` | The field name does not prove an actual boarding sensor event. Current ingestion accepts a timestamp no more than 60 seconds in the future; it has no source timezone/sequence fields. |
| `Ticket.passengerCount` | Positive integer | Party count; no seat/standing split. Existing simulated endpoint stores `DataOrigin.SIMULATED`. |
| `Ticket.idempotencyKey` | Unique database constraint/column | Deduplication within current SafarSetu namespace; no provider/event identity mapping. |
| `BusLocation` | Bus, lat/lon, timestamp, `DataOrigin` | Position sample only; not confirmed stop arrival. |
| `OccupancySnapshot` | Estimated count, optional seated count, quality/assumption | Seed/example data; current occupancy service does not use it as authoritative ticket-derived count. |

## Field availability matrix

| External concept | Available in locally accessible ETM files? | Current SafarSetu counterpart | Mapping status |
|---|---|---|---|
| Vendor / source system | No sample available | None | Unresolved |
| Device/machine ID | Unknown | None | Unresolved; proposed explicit `etm_devices` mapping |
| External bus/fleet ID | Unknown | `Bus.id` and unique `fleetCode` | Unresolved; never equate with `BUS-SIM-*` without evidence |
| External trip/run ID | Unknown | Unvalidated nullable string `Ticket.tripId` | Unresolved; a canonical relational run is proposed |
| Ticket/event ID and namespace | Unknown | `Ticket.id`, `idempotencyKey` | Unresolved; require provider-scoped event identity |
| Route ID / direction | Unknown | `Bus.route` and ordered `RouteStop` | Unresolved; do not match by similar route names |
| Boarding stop code | Unknown | `Stop.id` | Unresolved; `Stop` has no vendor code field |
| Destination/alighting stop | Unknown | `Ticket.destinationStop` | Unknown whether event source records destination or actual alighting |
| Event type/status | Unknown | No event type/status; `Ticket` is a passenger-count interval | Unresolved; ticket sold, boarding, alighting, cancel, refund must be distinguished |
| Event timestamp and timezone | Unknown | `Instant boardedAt` | Unresolved; source offset/clock and timestamp meaning must be documented |
| Passenger count | Unknown | Positive integer | Unresolved; multiplicity and corrections/refunds unknown |
| Sequence/replay/offline order | Unknown | No source sequence/watermark | Unresolved; current ticket IDs/idempotency catch duplicates only |
| Fare/passenger PII/payment | Unknown | Not modeled | Unresolved; minimize/avoid until privacy and payment scope are set |

## Mapping rules proposed (not implemented)

1. Namespace each source identifier by provider/system and entity type. A value such as `42` alone is not globally unique.
2. Create explicit reviewed rows linking source device, bus, route, stop, and trip IDs to canonical SafarSetu IDs, with validity dates and status. Enforce uniqueness for active source identifiers. Store who/when verified each mapping.
3. Require a real run record linking canonical bus + route + service date/start. Validate that each mapped stop is on that run's route and that boarding precedes destination.
4. Do not match by string similarity, display name, GPS proximity, or `BUS-SIM-*` values. Unknown/multiple mappings are quarantined and do not affect occupancy.
5. Preserve source event ID and provenance, event time and received time, source time zone/offset, sequence if supplied, and a normalized event payload hash. Retain raw payload only after privacy/retention approval.
6. Deduplicate on `(source_system, source_event_id)`. Exact same content is a replay; same key with changed content is a conflict requiring reconciliation. Keep provider ticket ID separate from event ID if they differ.
7. Until the source demonstrates actual boarding/alighting semantics, categorize records as ticketed/sold quantity. Do not call them observed onboard passengers. A destination selection is not proof of alighting.
8. Cancellations/refunds only change the specific lifecycle quantity supported by the source. Never silently overwrite confirmed bookings or erase the original event history.

## Evidence needed from the user/operator

Please make available locally at least one representative file per ETM export type, including headers/schema and a redacted sample with realistic identifier shapes. Also provide the vendor/protocol manual, device and fleet inventory, route/stop master data or official crosswalk, trip/run assignment source, event-type definitions, time zone/clock rules, sequence/replay behavior, cancellation/refund and boarding validation semantics, and privacy/retention constraints. Keep original files unchanged; copy sanitized samples into a review area if sensitive data is present.

## Proposed schema migration sequence (not approved or applied)

1. **Run context:** add `service_runs` with canonical ID, assigned bus, route, service date, scheduled/actual times, status, and uniqueness rules. Add nullable FK from event records; preserve existing `trip_id` strings until verified backfill. Do not infer historical production runs.
2. **Explicit identities:** add ETM device/provider identity and provider-scoped external ID mappings for bus, route, stop, and run, with unique active source keys and verification metadata. Final columns depend on actual source identifiers.
3. **Event ledger:** add normalized `etm_events` with source system/device/event ID, event type, run FK, resolved references, source/received timestamps, sequence, event result/status, and payload hash; add a unique source-event constraint and indexes. Raw payload column is deferred pending approved privacy/retention policy.
4. **Arrivals/alighting projection:** add per-run arrival state or normalized arrival events with route order, source event identity, timestamp, and unique/replay constraints; add explicit alighting/ticket lifecycle state only if source records it. Reject backward/duplicate conflicting arrivals.
5. **Future ATM booking (separate phase):** add bookings and booking-event/segment capacity reservation tables separately from ETM event ledger. Never count a booking as an observed boarding by default.

Each item is a proposal requiring schema review, backup/rollback plan, PostgreSQL access, and explicit approval before DDL. Current live database/schema state is unknown; no migration is safe to apply based on these source files alone.
