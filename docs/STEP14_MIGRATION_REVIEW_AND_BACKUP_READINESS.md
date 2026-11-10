# SafarSetu — Step 14 Migration Review and Backup Readiness

## Scope and outcome

This is a planning/review phase only. No SQL, backup, DDL, backend process, or database command was run. No project configuration or application source was changed.

The Step 13 migration draft is close to the reported schema baseline, but it contains two now-unnecessary ticket DDL operations and cannot yet be approved for execution. PostgreSQL client tools were not found on PATH or in the checked PostgreSQL 18 standard bin paths, so a backup cannot currently be made from this shell. A metadata export output file was also not found in the project; the review below uses the verified facts provided in the request and the source SQL/entity mappings.

## Files reviewed

- `docs/STEP13_DATABASE_MIGRATION_PLAN.md`
- `backend/db/migration/drafts/STEP13__bookings_and_simulated_arrivals_DRAFT.sql`
- `docs/STEP12_BACKEND_DATABASE_COMPATIBILITY_REPORT.md`
- `backend/db/diagnostics/step13_export_schema_metadata.sql`
- `backend/src/main/java/in/safarsetu/backend/entity/Bus.java`
- `backend/src/main/java/in/safarsetu/backend/entity/Stop.java`
- `backend/src/main/java/in/safarsetu/backend/entity/Ticket.java`
- `backend/src/main/java/in/safarsetu/backend/entity/PassengerBooking.java`
- `backend/src/main/java/in/safarsetu/backend/entity/SimulatedTripArrival.java`
- `backend/src/main/java/in/safarsetu/backend/repository/SimulatedTripArrivalRepository.java`
- `backend/src/main/java/in/safarsetu/backend/service/SimulatedArrivalService.java`
- `backend/src/test/java/in/safarsetu/backend/service/SimulatedArrivalServiceTest.java`
- SQL drafts V1–V6 under `backend/db/migration/` (reviewed in Step 13; V2 and V6 details are repeated below).

## Reviewed live-schema facts

The user-reported metadata export against PostgreSQL 18.6 / `safarsetu` verifies these seven existing `public` tables:

`buses`, `bus_locations`, `occupancy_snapshots`, `route_stops`, `routes`, `stops`, `tickets`.

It verifies that `passenger_bookings` and `simulated_trip_arrivals` are absent; `tickets.trip_id` exists as nullable `varchar(64)`; `idx_tickets_bus_trip_boarded_at` already exists on `(bus_id, trip_id, boarded_at)`; and `tickets.booking_id` is absent.

The export output itself was not saved in the project. The report therefore cannot confirm exact live types for `buses.id` / `stops.id`, or enumerate the existing constraints and indexes that must be retained. The Step 13 SQL source is an exporter, not the captured result. In the current shell, `pg_dump`, `pg_restore`, `psql`, and `createdb` are not in PATH, the standard `C:\Program Files\PostgreSQL\18\bin` and `C:\PostgreSQL\18\bin` client paths checked do not contain them, and a fresh listener probe did not see port 5432. This differs from the user's reported server state and may reflect different host/session visibility; no connection was attempted.

## Migration draft review

### Redundant DDL to remove from a reviewed revision

1. `ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS trip_id varchar(64);` is redundant because the verified live column already exists with the exact nullable `varchar(64)` mapping. The draft preflight checks the shape and the statement would be a no-op, but it should be removed from the final revision so the migration accurately represents the required delta.
2. `CREATE INDEX IF NOT EXISTS idx_tickets_bus_trip_boarded_at ON public.tickets (bus_id, trip_id, boarded_at);` is redundant because that named index already exists on the exact columns. The current preflight detects a same-name index with a different column expression, but the reviewed migration should omit recreation and retain a read-only preflight assertion for the existing index definition.
3. `tickets.booking_id` is confirmed absent, so `ALTER TABLE ... ADD COLUMN booking_id varchar(64)` is required. Keep it nullable, unique, and as a foreign key to the new `passenger_bookings(id)`. It must remain NULL for existing tickets; do not invent or backfill links.

The two new tables and the booking link are additive. Keep the draft's database/table/type preflight and transaction boundary. Its final `ROLLBACK` is a safety fuse: executing the draft against any database would still run DDL and take locks before it rolls back, so it is **not** a harmless live dry run. Do not execute it on `safarsetu`, even though the current file ends with `ROLLBACK`.

### Foreign-key column type review

The application mappings and draft agree:

| New FK column | Draft type | Referenced key from JPA entity | Source-level match | Live metadata proof |
|---|---|---|---|---|
| `passenger_bookings.bus_id` | `varchar(32)` | `buses.id`, `Bus.id` is varchar(32) | Yes | Pending: the saved export output does not provide the actual DB type here. |
| `passenger_bookings.boarding_stop_id` | `varchar(40)` | `stops.id`, `Stop.id` is varchar(40) | Yes | Pending. |
| `passenger_bookings.destination_stop_id` | `varchar(40)` | `stops.id`, `Stop.id` is varchar(40) | Yes | Pending. |
| `simulated_trip_arrivals.bus_id` | `varchar(32)` | `buses.id`, `Bus.id` is varchar(32) | Yes | Pending. |
| `simulated_trip_arrivals.stop_id` | `varchar(40)` | `stops.id`, `Stop.id` is varchar(40) | Yes | Pending. |
| `tickets.booking_id` | `varchar(64)` | new `passenger_bookings.id`, `PassengerBooking.id` is varchar(64) | Yes | Not an existing referenced key; new table is planned with matching key. |

Before execution, confirm the existing DB definitions of `buses.id` and `stops.id` from the actual column export. PostgreSQL requires compatible FK operators/types; matching JPA source annotations alone do not prove the live referenced columns match. Also check that there are no orphan or duplicate values if the metadata changes and `booking_id` is no longer empty/absent.

### Arrival uniqueness and application alignment

The proposed bus-scoped key `(bus_id, trip_id, stop_order)` is appropriate for the repository and service, both of which query/exclude duplicate arrivals by bus + trip + order. It matches the V2 draft. The entity currently declares `(trip_id, stop_order)` instead, so before rollout:

- Change `SimulatedTripArrival`'s unique constraint in `backend/src/main/java/in/safarsetu/backend/entity/SimulatedTripArrival.java` to include `bus_id` and use the same constraint name as the reviewed DDL (`uq_sim_arrival_bus_trip_order`).
- Keep `SimulatedTripArrivalRepository`'s `findTopByBus_IdAndTripIdOrderByStopOrderDesc` and `existsByBus_IdAndTripIdAndStopOrder` scope consistent.
- Extend `SimulatedArrivalServiceTest` with the contract that the same `tripId` and stop order may exist on two different buses, while a duplicate bus/trip/order is rejected. Add a PostgreSQL integration/concurrency check for the unique constraint as well; current Mockito tests do not exercise database uniqueness.
- Do not retain V2's separate non-unique `(bus_id, trip_id, stop_order)` index if the same columns are already covered by the unique constraint's B-tree.

No Java or test files were changed during this review.

### Booking-events table decision

Do not add `passenger_booking_events`. Current runtime uses the `PassengerBooking.status` state transition and the linked `Ticket` row directly. There is no entity, repository, service, or controller that writes/reads a booking event table. V6's event table is extra schema without a present runtime requirement; a future audit/event lifecycle needs a separately approved design.

## PostgreSQL client and backup readiness

`pg_dump`, `pg_restore`, `psql`, and `createdb` were not found in PATH or the checked common PostgreSQL 18 locations. Thus the backup command below is **prepared, not currently executable by name in this shell**. Locate the PostgreSQL 18 client binaries for the actual installation or add their existing bin directory to the current PowerShell session's PATH (do not change system PATH as part of this plan), then confirm `pg_dump --version` and `pg_restore --version` show PostgreSQL 18.x. PostgreSQL documents that `pg_dump` cannot dump from a server newer than its own major version. [PostgreSQL 18 `pg_dump` documentation](https://www.postgresql.org/docs/18/app-pgdump.html)

### Recommended custom-format backup command (not run)

Run from PowerShell only after confirming the correct PostgreSQL 18 client and server, connection to the existing `safarsetu` database, sufficient backup privileges, and the destination has adequate protected disk space. The destination is outside the project folder at `C:\Users\PC\SafarSetuBackups`. `--password` forces an interactive password prompt; no password is in the command or file name. PostgreSQL documents `-Fc` as custom format for `pg_restore` and `-W` as an interactive prompt. [PostgreSQL 18 `pg_dump` options](https://www.postgresql.org/docs/18/app-pgdump.html)

```powershell
$backupDirectory = 'C:\Users\PC\SafarSetuBackups'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFile = Join-Path $backupDirectory "safarsetu_pre_step14_$stamp.dump"
if (Test-Path -LiteralPath $backupFile) { throw "Backup path already exists; choose a new timestamp: $backupFile" }

pg_dump --host 127.0.0.1 --port 5432 --username postgres --dbname safarsetu `
  --format=custom --file $backupFile --password
if ($LASTEXITCODE -ne 0) { throw "pg_dump failed with exit code $LASTEXITCODE" }

Get-Item -LiteralPath $backupFile | Select-Object FullName, Length, LastWriteTime
Get-FileHash -LiteralPath $backupFile -Algorithm SHA256
```

The existing database owner is reported as `postgres`; if the approved backup operator uses another account, substitute that account rather than changing roles/passwords. Do not suppress stderr: inspect `pg_dump` warnings and require exit code 0 and a non-empty backup file. A database dump does not include cluster-global roles/tablespaces; for a restore into the same cluster the reported `postgres` role already exists, while a different cluster needs separate approved role provisioning/ownership mapping.

### Verify archive without restoring

Use a PostgreSQL 18-compatible `pg_restore` client. The list operation reads the custom archive and does not connect to or modify a database. It checks that the archive catalog is readable; it is not a substitute for a full restore test. PostgreSQL documents `pg_restore --list` for inspecting the archive TOC. [PostgreSQL 18 `pg_restore` documentation](https://www.postgresql.org/docs/18/app-pgrestore.html)

```powershell
$toc = & pg_restore --list $backupFile
if ($LASTEXITCODE -ne 0 -or -not $toc) { throw 'Backup archive could not be listed' }
$toc | Select-Object -First 30
Get-FileHash -LiteralPath $backupFile -Algorithm SHA256
```

Record the SHA-256 and file size in the approved backup log, stored separately from the project. Protect the dump as sensitive: it contains a copy of all database data.

### Restore test on a separate disposable database (not run)

After separate approval to create a disposable database, confirm the proposed name does not already exist and is never `safarsetu`. Use a unique test name and `template0`; restore with no `--clean`/`--create` options so the command cannot target or drop the source database:

```powershell
$restoreDatabase = "safarsetu_restorecheck_$stamp"
# Refuse the production database name and verify this disposable name is unused.
if ($restoreDatabase -eq 'safarsetu') { throw 'Refusing to restore into the production database name' }
$exists = & psql -X --host 127.0.0.1 --port 5432 --username postgres `
  --dbname postgres --tuples-only --no-align --set ON_ERROR_STOP=1 `
  --command "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$restoreDatabase');" --password
if ($LASTEXITCODE -ne 0) { throw "Could not verify disposable database name: $LASTEXITCODE" }
if ($exists.Trim() -ne 'f') { throw 'Disposable restore database already exists or returned an unexpected result' }

createdb --host 127.0.0.1 --port 5432 --username postgres `
  --maintenance-db postgres --template template0 --owner postgres `
  --password $restoreDatabase
if ($LASTEXITCODE -ne 0) { throw "Disposable database creation failed: $LASTEXITCODE" }

pg_restore --host 127.0.0.1 --port 5432 --username postgres `
  --dbname $restoreDatabase --exit-on-error --verbose --password $backupFile
if ($LASTEXITCODE -ne 0) { throw "Restore test failed: $LASTEXITCODE" }
```

Then query the **disposable** database read-only: verify the seven expected tables, compare row counts for each existing table to the pre-dump baseline, and inspect constraints/indexes. The test target must remain distinct from `safarsetu`. Do not run `DROP DATABASE` automatically; cleanup is destructive and requires separate approval after verifying the target name and that it contains only the disposable restore. A successful archive listing alone is not a successful restore test.

## Unresolved risks and approval checklist

- [ ] Save/review the actual Step 13 export output; verify exact `buses.id` and `stops.id` DB types, all existing constraints, and the actual ticket index definition.
- [ ] Find/verify PostgreSQL 18.x `pg_dump`, `pg_restore`, and `createdb` paths; tool commands currently are not available in PATH/common paths checked.
- [ ] Run the custom-format backup with exit code 0; verify nonzero size, SHA-256, and `pg_restore --list` output.
- [ ] Perform an approved restore test in a distinct disposable database; compare existing row counts/schema and retain evidence. Never restore to `safarsetu`.
- [ ] Revise the migration to omit the redundant `trip_id` column addition and existing ticket index creation; retain read-only assertions for their existing shape.
- [ ] Verify `tickets.booking_id` is absent as reported; add nullable `varchar(64)`, uniqueness, and FK only after confirming the referenced IDs and no conflicting schema state. Do not backfill.
- [ ] Add only the two runtime-mapped tables; omit `passenger_booking_events`.
- [ ] Align the JPA arrival uniqueness and tests with `(bus_id, trip_id, stop_order)`; review the redundant V2 index.
- [ ] Have a reviewer approve the exact migration revision/hash, maintenance window, backup/restore evidence, and postflight checks before any DDL is executed.

**Execution approval is not present.** This request authorizes review and documentation only; it does not authorize the backup, disposable database creation/restore, migration execution, schema change, or backend startup.
