# SafarSetu — Step 13 Database Migration Plan

## Status: planning only — no database changes authorized or performed

This phase created one read-only metadata export script and one clearly marked migration draft. Neither was executed. The Spring Boot backend was not started; no settings, database records, or existing files were changed. The seven existing public tables and all their data must be preserved.

## Source and schema findings

The backend maps nine entities:

- Existing tables reported in `public`: `buses`, `bus_locations`, `occupancy_snapshots`, `route_stops`, `routes`, `stops`, and `tickets`.
- Missing mapped tables: `passenger_bookings` and `simulated_trip_arrivals`.
- Existing ticket columns `trip_id` and `booking_id` are not confirmed from the provided table inventory; their presence, types, nullability, constraints, and indexes must be checked before migration.

The mappings require a nullable `tickets.trip_id varchar(64)` and a nullable, unique `tickets.booking_id varchar(64)` foreign key to `passenger_bookings.id`. Existing `trip_id` values must be preserved. The draft adds either column only when absent and never assigns a trip or booking to an existing ticket. If `booking_id` exists and has any non-null values while the booking table is absent, the draft aborts for manual reconciliation; it never fabricates a relationship.

`PassengerBookingService` requires the booking table for booking writes, trip/segment capacity checks, idempotency, and receipt lookups. `BusService` counts active confirmed reservations separately from ticket-derived passengers on `[boardingStopOrder, destinationStopOrder)`, and the booking-to-ticket link moves the booking to `BOARDING_RECORDED_SIMULATION` to avoid double counting. No booking or arrival persistence can be verified or used until the corresponding tables are present.

## Files created

1. `backend/db/diagnostics/step13_export_schema_metadata.sql` — read-only catalog and `information_schema` export for the seven existing tables plus the two expected targets. It reports table existence, ordered column details including types/nullability/defaults/identity, PK/unique/FK/check definitions and validation state, and index definitions. It does not select application data or expose secrets. It wraps queries in `BEGIN TRANSACTION READ ONLY` / `COMMIT`.
2. `backend/db/migration/drafts/STEP13__bookings_and_simulated_arrivals_DRAFT.sql` — proposed additive migration, clearly marked **DRAFT ONLY**. It has database/baseline/table/type preflight checks, bounded lock and statement timeouts, conditional nullable ticket columns, definitions for the two missing tables, booking foreign-key/unique checks, and postflight catalog checks. It ends with `ROLLBACK` by design; it cannot persist its DDL as written. It is not a production migration, and must be reviewed/adjusted after the metadata export and explicit approval. Do not execute it.
3. `docs/STEP13_DATABASE_MIGRATION_PLAN.md` — this plan, prerequisites, risk/rollback notes, verification and approval boundary.

## Read-only metadata export

After confirming connectivity to the intended existing database, the metadata script can be run by the database owner using `psql`. The connection password is entered by the client prompt, not placed in command history or printed:

```powershell
psql -X -U postgres -d safarsetu -v ON_ERROR_STOP=1 -f backend/db/diagnostics/step13_export_schema_metadata.sql
```

Review the output before adapting the migration. Confirm that `current_database()` is `safarsetu` and that the seven existing tables are in `public`. Capture and preserve the output in the approved project record if desired; do not include credentials. If PostgreSQL is not reachable from the shell, resolve that connection/host context before proceeding. The earlier Step 12 runtime probe did not find `psql`, DB environment variables, or a listener on local port 5432, despite the user-reported PostgreSQL 18.6 instance; the metadata script was not run in this phase.

The export does not inspect row contents. Before any approved migration, separately record baseline row counts for the seven tables and ensure a verified backup/restore point exists. Avoid copying passenger/ticket rows into the report.

## Proposed migration contents and decisions

### `passenger_bookings`

The draft follows the runtime entity: ID/reference/idempotency key; trip ID; bus and boarding/destination stop references; positive passenger quantity; supported simulated booking status; and created timestamp. It adds the `(bus_id, trip_id, created_at)` lookup index and unique booking reference/idempotency constraints. The bus/stop FK types must match existing primary keys. The table has no passenger identity, fares, payments, physical seats, or cancellation workflow.

### `simulated_trip_arrivals` and unique-key reconciliation

The V2 SQL currently has unique `(bus_id, trip_id, stop_order)` but `SimulatedTripArrival` currently declares unique `(trip_id, stop_order)`. The selected design is **bus-scoped trip identity**, using `(bus_id, trip_id, stop_order)` because the repository's read/existence methods filter on bus, trip, and order, and this avoids collisions if trip IDs are reused across buses. The proposed draft uses that unique key and omits V2's duplicate non-unique index on the identical column sequence (the unique constraint already creates a B-tree index).

Before deployment, update the JPA `SimulatedTripArrival` table constraint to match `(bus_id, trip_id, stop_order)`, and review arrival service semantics/tests. No Java source was changed in this planning phase. If the product instead guarantees globally unique trip IDs, revise the decision consistently in repository, entity, and migration before approval.

### Ticket columns and data preservation

- `trip_id`: if absent, add nullable varchar(64) only. Do not apply V1's fixture-specific backfill in this plan. If present, retain every value and require it to match the mapped nullable type.
- `booking_id`: if absent, add nullable varchar(64), then add a unique constraint and FK to the new booking table. If present, verify type/nullability and inspect values/constraints. The draft aborts if any non-null value exists because there is no booking table to validate those links; no IDs are invented or inferred.
- Add/confirm the ticket lookup index `(bus_id, trip_id, boarded_at)`. If a same-name index exists with a different definition, stop and reconcile instead of relying on `IF NOT EXISTS`.
- Existing bus, route, stop, ticket, location, route-stop, and occupancy-snapshot records are never updated, deleted, or reinserted by the proposal.

### `passenger_booking_events`

Do **not** create this table in the proposed migration. Current runtime has no entity, repository, service, or controller using it. A future booking lifecycle may justify an append-only event ledger, but its event types, idempotency, retention, and query use need a separate design. V6's draft event table is not required for the currently implemented booking state flow.

## Preconditions before any execution

1. Run and review the read-only metadata export against the actual `safarsetu` database. Confirm it is the expected PostgreSQL 18.6 instance and schema.
2. Compare every mapped column's PostgreSQL type/length, nullability/default, primary key, FK, unique/check constraint, and index with the output. Resolve any unexpected column or constraint before using the draft.
3. Inspect whether `tickets.trip_id` and `tickets.booking_id` already exist; inspect non-null `booking_id` values without exposing ticket contents in this report. Confirm there is no user booking data in target tables; the expected booking table was reported absent.
4. Verify all required referenced key types and that existing bus/stop rows satisfy the new FKs. Capture row counts for existing tables and prove a backup can be restored.
5. Reconcile the arrival unique key in entity/source/tests with the bus-scoped decision. Decide whether an index of the intended name already exists with the correct definition.
6. Select an actual migration/versioning process. No Flyway/Liquibase runner is currently configured; the draft is not auto-discovered or executable as a managed migration. Keep Hibernate `DDL_AUTO=validate` and `SEED_DEMO_DATA=false` for subsequent backend validation; do not use `update`.
7. Test an approved revision against a disposable clone restored from the backup, and compare schema, constraint, and existing row counts before/after.

## Preflight and post-migration verification

The draft includes preflight guards to require `current_database() = 'safarsetu'`, all seven baseline tables, absent target tables, compatible bus/stop IDs, and compatible existing ticket context columns. It rejects pre-existing non-null booking links rather than inventing a mapping. Keep those abort conditions; if the metadata differs, revise the script only after review.

Before a future approved commit, run read-only checks for:

- All nine expected tables in `public`.
- The `tickets.trip_id` and `tickets.booking_id` SQL types/nullability.
- Booking PK, unique reference/idempotency, bus/stop FKs, positive quantity/status constraints and lookup index.
- Ticket booking FK and uniqueness, plus ticket trip lookup index.
- Arrival bus/stop FKs, nonnegative order/alighting checks, string data-origin check, and the chosen bus-scoped unique key.
- Unchanged baseline counts for `buses`, `bus_locations`, `occupancy_snapshots`, `route_stops`, `routes`, `stops`, and `tickets`.

The draft's postflight checks cover table/column/constraint/index presence, then its final `ROLLBACK` leaves the database unchanged even if someone runs it accidentally. A later explicitly approved application copy would need an operator-reviewed transaction decision; do not simply replace the rollback with commit without the approval below.

## Risks and rollback considerations

- DDL takes locks on `tickets` and creates foreign keys/indexes. The draft uses a 5-second lock timeout and 30-second statement timeout; timeouts should abort rather than wait indefinitely. Actual lock duration and load impact still require maintenance planning.
- PostgreSQL DDL is transactional for these operations. Before commit, any failure should roll back the entire transaction. The current file ends in `ROLLBACK` intentionally.
- After an approved commit, a schema rollback must not drop new tables/columns blindly. First determine whether any booking or arrival rows have been written. Prefer rolling back the application code while retaining additive schema/data; remove schema only with a verified backup, explicit data-retention decision, and separate approval.
- The existing data is not copied, transformed, backfilled, or deleted by the proposal. Existing ticket associations remain null unless a future operator supplies a verified mapping under a separately approved process.
- Hibernate `validate` is not a substitute for checking constraint/index definitions or a migration runner. It is expected to fail today because both mapped tables are absent.

## Exact approval required before execution

No schema-changing SQL may be executed until the owner explicitly approves **all** of the following on the confirmed existing `safarsetu` database: (1) the reviewed metadata export and backup/restore point; (2) the exact revised migration file/hash; (3) adding `passenger_bookings` and `simulated_trip_arrivals`; (4) adding `tickets.trip_id` and/or `tickets.booking_id` only if the reviewed metadata confirms they are absent and compatible; (5) the unique/FK/index/check definitions; (6) the bus-scoped arrival uniqueness decision and corresponding Java entity update; and (7) a maintenance window and postflight plan. This request authorizes planning only, so no execution approval is inferred.
