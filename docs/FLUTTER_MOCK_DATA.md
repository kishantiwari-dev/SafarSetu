# Flutter mock-data scenarios

`MockBusRepository` exposes only stable stop IDs and bus scenarios on a seeded simulated route that contains the selected boarding stop before the destination. An unknown stop pair, same-stop pair, reverse journey, or a query containing `mars` returns no buses instead of inventing a match. All fixture routes are simulation corridors in Noida and Greater Noida, not published services.

The client fixture mirrors the backend's 22 approximate stops and 8 simulated route sequences. It has 9 bus scenario records:

- Low and moderate loads: `BUS-SIM-001`, `BUS-SIM-002`, and `BUS-SIM-006`.
- High and nearly full loads: `BUS-SIM-003`, `BUS-SIM-004`, and `BUS-SIM-007`.
- Missing ticket data: `BUS-SIM-005`; occupancy remains unknown.
- Missing location: `BUS-SIM-005`.
- Stale location: `BUS-SIM-008` (24 hours old in the scenario).
- Invalid passenger count above total capacity: `BUS-SIM-009`; the app withholds occupancy and seat estimates.

Passenger counts are scenario values, not live ticket events. Demo searches return three distinct simulated trips for a supported ordered stop pair (36%, 64%, and 96% of seating capacity). The database fixtures remain separate and insert-only: 13 buses, 23 synthetic ETM tickets, 19 synthetic locations, and 13 snapshots, as documented in [the backend dataset reference](../backend/DATASET_DOCUMENTATION.md). Local demo favourites and recent journeys are stored in browser/device preferences and do not represent server-side accounts.

Stop coordinates mirror existing backend fixture values and remain `APPROXIMATE`. The map joins journey stop points only to show a clearly labeled schematic corridor; it does not calculate road geometry. The simulated location marker and timestamps are not live transport information.
