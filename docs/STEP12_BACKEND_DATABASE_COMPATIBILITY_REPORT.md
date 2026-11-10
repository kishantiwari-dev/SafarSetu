# SafarSetu — Step 12 Backend/Database Compatibility Audit

## Scope and evidence boundary

This was a read-only source/configuration audit. No backend was started and no database statement was issued. The supplied live-schema inventory names seven tables in `public`: `buses`, `bus_locations`, `occupancy_snapshots`, `route_stops`, `routes`, `stops`, and `tickets`; it also says `passenger_bookings` is absent.

The per-table output from `information_schema.columns` was not included, so the actual live column names, SQL types, lengths, nullability, defaults, constraints, foreign keys, and indexes cannot be verified from the supplied information. In this execution environment, `psql` was not on PATH, no DB connection variables were present, and a fresh socket inspection did not see a listener on port 5432. That conflicts with the user-reported PostgreSQL 18.6 running locally; environment/host visibility may differ. No credentials were guessed and none were printed. Accordingly, this report gives exact source-side expectations, identifies definite missing tables from the supplied inventory, and marks all unprovided live column-level comparisons as **not verified**.

## Entity-to-table mapping matrix

Java field types below indicate Hibernate/JPA expectations under the project's Spring Boot naming strategy: camelCase becomes snake_case, `String` becomes a character column, integer fields become integer, booleans become boolean, doubles become double precision, enums use their string names, and `Instant` is a timestamp-with-time-zone value on PostgreSQL. Exact PostgreSQL metadata must be compared directly before calling existing columns compatible.

| Entity / mapping | Expected columns and core constraints from source | Supplied live schema result |
|---|---|---|
| `Route` → `routes` | `id` varchar(32) PK; `name` varchar(120) NOT NULL; `data_origin` string enum NOT NULL (`SIMULATED`, `REAL`); `active` boolean NOT NULL. | Table exists. Column/type/nullability/FK/index comparison unavailable. |
| `Stop` → `stops` | `id` varchar(40) PK; `name` varchar(140) NOT NULL; `latitude`, `longitude` double precision NOT NULL; `verification_status` string enum NOT NULL (`VERIFIED`, `APPROXIMATE`, `UNVERIFIED`); coordinate range check declared. | Table exists. Column/type/nullability/constraint comparison unavailable. |
| `Bus` → `buses` | `id` varchar(32) PK; `fleet_code` varchar(32) NOT NULL UNIQUE; `seating_capacity` integer NOT NULL; `total_passenger_capacity` nullable integer; `route_id` required FK to `routes.id`; `data_origin` string enum NOT NULL; `active` boolean NOT NULL; positive/ordering capacity check declared. | Table exists. Column/type/nullability/FK/unique/check/index comparison unavailable. |
| `RouteStop` + `RouteStopId` → `route_stops` | Composite PK `(route_id, stop_id)`; both required FKs to `routes.id` and `stops.id`; `stop_order` integer NOT NULL; unique `(route_id, stop_order)`; index on `stop_id`; nonnegative-order check declared. Sequence contiguity is additionally enforced by service code. | Table exists. Column/type/PK/FK/unique/index/check comparison unavailable. |
| `Ticket` → `tickets` | `id` varchar(64) PK; `idempotency_key` varchar(100) NOT NULL UNIQUE; `trip_id` nullable varchar(64); required FKs `bus_id`, `boarding_stop_id`, `destination_stop_id`; nullable `booking_id` FK to `passenger_bookings.id`, UNIQUE; `passenger_count` integer NOT NULL; `boarded_at` timestamp with time zone NOT NULL; `data_origin` string enum NOT NULL; positive-count check; indexes `(bus_id, boarded_at)` and `(bus_id, trip_id, boarded_at)`. | Table exists. The inventory does not say whether `trip_id` or `booking_id` exists, or provide any other column/constraint metadata. V1 drafts `trip_id`; V6 drafts `booking_id`. |
| `BusLocation` → `bus_locations` | `id` varchar(64) PK; required FK `bus_id` to `buses.id`; `latitude`, `longitude` double precision NOT NULL; `recorded_at` timestamp with time zone NOT NULL; `data_origin` string enum NOT NULL; coordinate range check; index `(bus_id, recorded_at)`. | Table exists. Column/type/nullability/FK/index/check comparison unavailable. |
| `OccupancySnapshot` → `occupancy_snapshots` | `id` varchar(64) PK; required FK `bus_id`; `snapshot_at` timestamp with time zone NOT NULL; `estimated_onboard` integer NOT NULL; nullable integer `seated_passengers`; `data_quality` string enum NOT NULL (`COMPLETE`, `NO_TICKET_DATA`, `STALE`, `INCONSISTENT`); nullable `assumptions` varchar(300); index `(bus_id, snapshot_at)`. | Table exists. Column/type/nullability/FK/index comparison unavailable. |
| `PassengerBooking` → `passenger_bookings` | `id` varchar(64) PK; `booking_reference` varchar(64) NOT NULL UNIQUE; `idempotency_key` varchar(100) NOT NULL UNIQUE; `trip_id` varchar(64) NOT NULL; required FKs `bus_id`, `boarding_stop_id`, `destination_stop_id`; `passenger_count` integer NOT NULL and positive; `status` varchar(32) NOT NULL; `created_at` timestamp with time zone NOT NULL; index `(bus_id, trip_id, created_at)`. | **Absent** from supplied public table inventory. Definite incompatibility. |
| `SimulatedTripArrival` → `simulated_trip_arrivals` | `event_id` varchar(64) PK; required FKs `bus_id`, `stop_id`; `trip_id` varchar(64) NOT NULL; `stop_order` integer NOT NULL; `arrived_at` timestamp with time zone NOT NULL; `simulated_alighting_passengers` integer NOT NULL; `data_origin` varchar(16) NOT NULL; unique `(trip_id, stop_order)` declared in entity; index `(bus_id, trip_id, stop_order)`. | Absent from the supplied seven-table inventory. Definite incompatibility. |

`RouteStopId` is an `@Embeddable`, not a separate table. `DataOrigin`, `VerificationStatus`, and `DataQuality` are string-persisted enums, not entities/tables.

### Column-level mismatches and limits

1. **Definite table mismatch:** `passenger_bookings` is required by a mapped entity/repository but absent from the supplied schema inventory.
2. **Definite table mismatch:** `simulated_trip_arrivals` is mapped by an entity/repository but absent from the supplied seven-table inventory.
3. **Ticket column requirements:** backend source now maps nullable `tickets.trip_id` and nullable unique `tickets.booking_id`; V1 and V6 drafts add them. Their actual presence and types in the live `tickets` table were not specified, so those are unresolved—not verified absent.
4. **Other existing-table columns:** table names alone are insufficient to compare required columns or their types/nullability. No specific live column mismatch, FK, unique key, or index can responsibly be asserted for the other six present tables without the metadata output.
5. Entity-declared JPA `@Index`, unique constraints, and `@Check` constraints represent source expectations. Hibernate `validate` primarily checks mapped table/column compatibility; it should not be treated as a complete audit that all PostgreSQL indexes, FK/unique/check definitions match.

## Booking persistence and occupancy

`PassengerBookingService` saves a `PassengerBooking` record after checking the bus, synthetic trip ID, ordered route stops, existing same-trip ticket journeys, and existing confirmed bookings against total passenger capacity. It uses a transaction and locks the bus row through the repository's `findByIdForUpdate`; PostgreSQL behavior has not been tested in this audit. `PassengerBookingRepository` reads booking rows for bus/trip/status and lookup by booking reference/idempotency key. All require the missing `passenger_bookings` table.

`Ticket` has an optional many-to-one relationship through `tickets.booking_id`. `TicketService` accepts a booking link only for a matching confirmed simulation booking (same bus, trip, segment, and quantity), saves the ticket, and transitions that booking to `BOARDING_RECORDED_SIMULATION`. The booking row therefore stops contributing to the reservation count while its ticket event contributes to ticket-derived occupancy. The DB relationship also expects `tickets.booking_id` to be nullable, unique, and a foreign key to `passenger_bookings(id)`.

`BusService` occupancy reads ticket events and bookings, scopes each to the selected bus/trip and route segment `[boardingStopOrder, destinationStopOrder)`, counts only status `CONFIRMED_SIMULATION` as reserved, and excludes linked booking rows from the reservation sum to avoid double counting. Ticket-derived passengers are distinct from reserved passengers; remaining passenger capacity is based on the combined unique load. These code paths cannot run against the supplied schema as-is because the booking table is missing. A missing booking table also prevents repository/entity initialization and passenger booking persistence.

V6 also drafts a `passenger_booking_events` table, but there is no corresponding entity/repository/event persistence workflow in `backend/src/main`. It is not required by the current mapped booking persistence path; the draft should not be applied as-is without a design decision.

## Configuration and migration assessment

- `backend/pom.xml` uses Spring Boot 4.1.1, Java 21, Spring MVC, Spring Data JPA, Validation, and the PostgreSQL JDBC driver.
- `application.yml` uses `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`; it has no database credential defaults. Default profile is `dev`, server port defaults to 8080, and base Hibernate setting is `validate`.
- `application-dev.yml` overrides Hibernate to `${DDL_AUTO:update}` and insert-only demo seed to `${SEED_DEMO_DATA:true}`. For any validation-only startup, both must be explicitly set to `validate` and `false`; do not rely on defaults.
- `application-prod.yml` forces `validate`, disables seed, and sets PostgreSQL `sslmode=verify-full`; it is not a local shortcut unless the TLS/CA requirements are satisfied.
- No Flyway or Liquibase dependency/runner was found. V1–V6 are manually maintained SQL drafts, not an automatically executed migration sequence.
- V1 adds nullable `tickets.trip_id`, backfills a listed set of stable ticket IDs, and adds a ticket index. It assumes an existing `tickets` table and must be checked against the existing data before use.
- V2 creates `simulated_trip_arrivals` with unique `(bus_id, trip_id, stop_order)`, while the entity declares unique `(trip_id, stop_order)` without `bus_id`. Reconcile the trip-identity invariant and align source and SQL before migration. V2 table itself is absent per the supplied inventory.
- V3–V5 are future service-run/vendor mapping/event-ledger proposals without corresponding current runtime entities. Keep deferred pending approved trip semantics and vendor data.
- V6 drafts passenger bookings, the ticket `booking_id` relationship, and an unmapped booking-event table. The booking table is absent. Do not execute this draft until reviewed against the existing tables/data and completed migration plan.

## Is `DDL_AUTO=validate` startup expected to succeed?

**No. Based on the supplied table inventory, startup with Hibernate `validate` is expected to fail.** At least the mapped tables `passenger_bookings` and `simulated_trip_arrivals` are missing. The `Ticket.booking` mapping also references `passenger_bookings`, and the existing `tickets.booking_id` column is unverified. Hibernate table validation should reject the missing mapped tables before the backend can serve requests. Column-level failures may also arise once those tables exist, because metadata for the current seven tables and the new ticket columns was not provided.

Do not switch to `update`. That could alter the existing schema, create tables/columns, and—under dev defaults—run the data seeder. Do not run V1–V6 as a shortcut; there is no migration runner and no inspected backup/schema diff.

## Safest recommended next action

Obtain a **read-only schema metadata export** from the same PostgreSQL instance that contains all columns (schema/table/column, `data_type`, `udt_name`, length/precision, `is_nullable`, and default), plus primary/unique/foreign-key constraints and index definitions for `public`. Ensure the query runs against `safarsetu` and disclose no credential. The current runtime check did not see port 5432 and no `psql` or DB variables were available, so resolve that environment/connection discrepancy before treating the reported schema as reachable from this workspace.

After the metadata comparison and backup/recovery planning, design a reviewed migration for the two missing tables and any required ticket columns/constraints, reconcile V2 uniqueness, and decide whether `passenger_booking_events` is intentionally out of scope. Only after an explicit migration approval should the schema be changed. Then run backend with `DDL_AUTO=validate` and `SEED_DEMO_DATA=false`; verify startup and a DB-backed endpoint. No backend/database action was taken for this audit.
