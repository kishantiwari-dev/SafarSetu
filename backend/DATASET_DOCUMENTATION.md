# Gautam Buddha Nagar development dataset

## Geographic scope and provenance

The local development seeder creates a synthetic network covering selected parts of Noida, Greater Noida, Greater Noida West, Kasna, Dadri, and connecting corridors. Its **9 bus routes are simulation scenarios**, not claims that a public operator runs these routes. Bus fleet codes, tickets, passenger counts, and GPS positions are synthetic. No operator, service number, fare, timetable, or live operation is represented.

The [NMRC station list](https://www.nmrcnoida.com/StationList) verifies names and published order for the NMRC Aqua Line reference stations, including Sector 51, Sector 76, Sectors 137/142/148, Knowledge Park II, Pari Chowk, Alpha-1, Delta-1, GNIDA Office, and Depot. It does not verify bus service or the stops' coordinates. The [NMRC 2019 feeder-route PDF](https://www.nmrcnoida.com/writereaddata/Portal/images/Pdf/Summary-of-new-Route-With-Route-Code-25032019.pdf) currently returns NMRC's Page Not Found response, so it is not used as route evidence. Botanical Garden, Sector 18/Atta Market, Sector 62, Kasna, university locations, Surajpur, Dadri Railway Station, Kisan Chowk, and Greater Noida West are candidate points, not NMRC stations.

All 22 seeded stops have `APPROXIMATE` coordinates entered for prototype locality and visualization. No coordinate is marked `VERIFIED`, and no surveyed or official stop-coordinate data was available for this seed. Route sequences are geographic mock corridors. Even where a sequence follows named metro stations, it remains a simulated bus route.

## Routes and stop order

| Simulated route | Ordered stops | Bus |
|---|---|---|
| `SIM-GN-001` | Botanical Garden → Sector 18/Atta Market → Sector 62 → Knowledge Park II → Pari Chowk → Alpha 1 | `BUS-SIM-001`, `BUS-SIM-009`, `BUS-SIM-010` |
| `SIM-GN-002` | Sector 62 → Sector 51 → Sector 76 → Knowledge Park II → Delta 1 → Greater Noida Authority | `BUS-SIM-002` |
| `SIM-GN-003` | Gaur City → Kisan Chowk → Greater Noida West → Sector 51 → Sector 62 | `BUS-SIM-003` |
| `SIM-GN-004` | Kasna → Sharda University → Gautam Buddha University → Surajpur → Delta 1 → Pari Chowk | `BUS-SIM-004` |
| `SIM-GN-005` | Sector 51 → Sector 76 → Sector 137 → Sector 142 → Sector 148 → Knowledge Park II | `BUS-SIM-005` |
| `SIM-GN-006` | Dadri Railway Station → Gautam Buddha University → Kasna → Knowledge Park II → Pari Chowk → Depot | `BUS-SIM-006` |
| `SIM-GN-007` | Knowledge Park II → Pari Chowk → Alpha 1 → Delta 1 → Greater Noida Authority → Depot | `BUS-SIM-007` |
| `SIM-GN-008` | Sector 18/Atta Market → Botanical Garden → Sector 51 → Greater Noida West → Gaur City | `BUS-SIM-008` |
| `SIM-GN-009` | Alpha 1 → Pari Chowk → Knowledge Park II → Sector 62 → Sector 18/Atta Market → Botanical Garden | `BUS-SIM-011`, `BUS-SIM-012`, `BUS-SIM-013` |

Route order belongs to `route_stops`, so the same stop may appear in several routes at a different sequence. A route-stop pair is keyed by route and stop; `(route_id, stop_order)` is also unique and stop order must be nonnegative.

## Dataset contents and generation

The fixed fixture set contains 22 stops, 9 routes, 52 route-stop associations, 13 buses, 23 ETM ticket events, 19 GPS/location records, and 13 occupancy snapshots. Route 001 has three options at Knowledge Park II: 9 passengers aboard on 35 seats (26%), 32 on 50 seats (64%), and 48 on 50 seats (96%). Route 009 has three reverse-route options with 18, 32, and 48 passengers aboard on 50 seats (36%, 64%, and 96%). These provide Normal, Moderately crowded, and Overcrowded examples. All generated buses, tickets, locations, and route definitions are marked `SIMULATED`; they are not live GPS/ETM data. Each ticket is assigned a deterministic per-bus demo `tripId` (`SIM-TRIP-{busId}-DEMO-01`), so separate service trips are not aggregated. Stable IDs and uniqueness constraints protect repeat runs. The dev-profile initializer checks each ID before inserting; it does not update existing rows or clear tables.

The event history has low, medium, and high passenger loads. It covers parties boarding at intermediate stops and exiting before later boarding events. Search occupancy is passengers aboard divided by seating capacity; estimated available seats are `max(0, seatingCapacity - onboardPassengers)`. Shared crowding defaults are configured in `application.yml`: under 40% Normal, 40–69% Moderately crowded, 70–89% Crowded, and 90% or more Overcrowded. `BUS-SIM-005` has no ticket events; its `NO_TICKET_DATA` snapshot's zero is explicitly not an observed passenger count.

The 13 seeded `OccupancySnapshot` rows are development examples only. The occupancy endpoint now derives route-stop estimates from ticket rows and does not use snapshots as a fallback or create snapshots during calculation.

GPS records are placed at or a small fixed offset from stops along the assigned bus route. Six buses have three ordered records each; `BUS-SIM-008` has one deliberately stale record; `BUS-SIM-005` has no location record. Normal track timestamps are anchored to the seeder's UTC startup minute with fixed offsets. The latest normal point aligns with the startup minute, while the selected stale point is 24 hours before the seed time anchor. Stable IDs mean a populated database keeps its original seed timestamps on restarts; resetting a disposable database and seeding it again creates a new time anchor. A database seeded by an earlier version retains its older fixture timestamps until a developer deliberately reseeds a disposable database.

Ticket and location timestamps use `Instant` (UTC). Ticket events are generated in increasing per-bus time order. Location records are ordered by recorded time. GPS data is synthetic and does not represent a live vehicle or a surveyed road position.

## Seeding and safe reset

Seeding is enabled only by the default `dev` profile and can be disabled with `SEED_DEMO_DATA=false`. Configure `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` before startup. Hibernate's local `DDL_AUTO=update` creates or extends the schema without deleting existing rows. No database is created automatically.

Restarting the application against the same database is the repeat-seed check: stable keys prevent duplicate fixtures, and pre-existing rows are left unchanged. To regenerate the time-relative fixture, stop the service and manually drop/recreate only a disposable local development database after verifying `DB_URL`. Never run a reset against a database with user or production data. The seeder itself never performs a reset.

For a database created before trip IDs were added, apply [`db/migration/V1__ticket_trip_context.sql`](db/migration/V1__ticket_trip_context.sql). It adds the nullable column, backfills only the known simulated ticket IDs, and creates an index without deleting rows. Other preexisting ticket records remain unassigned and occupancy will report that their trip context is unknown.

## Known limits

- These fixtures do not establish real public transit coverage, schedules, fares, operator identity, or bus availability.
- Coordinates are approximate and not suitable for navigation, geofencing, or accuracy claims.
- The ticket records are party counts, not seated/standing breakdowns; available seats cannot be inferred authoritatively.
- Missing and stale records are deliberate test cases. A zero snapshot marked `NO_TICKET_DATA` is not a measured zero.
- Seeding and model tests using repository doubles do not verify PostgreSQL DDL, indexes, constraints, or transaction behavior. Use a PostgreSQL instance for those integration checks.
- Hibernate `ddl-auto=update` is the current local schema initializer; no Flyway/Liquibase migration history exists yet. Adopt reviewed migrations before production use.
