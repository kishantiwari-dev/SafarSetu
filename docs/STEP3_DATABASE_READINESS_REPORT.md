# SafarSetu + ATM — Step 3 Database and Backend Runtime Readiness

## Summary

**The backend is not ready for a live database startup yet.** PostgreSQL executables were not found in PATH or the checked common installation directories; the PostgreSQL service query was denied by Windows Service Control Manager permissions; and neither port 5432 nor 8080 had a listener. The current local database's existence, contents, schema, and backup state are therefore **unknown**. The process environment had no `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, profile, schema-mode, or seed override variables.

No service was started or stopped, no database was connected to, no migration was executed, and no database or configuration contents were changed. A normal startup with the default `dev` profile is unsafe before inspection: it defaults Hibernate to `update` and enables insert-only demo seeding.

## Environment findings

| Check | Result |
|---|---|
| `postgres`, `pg_ctl`, `psql` in PATH | Not found |
| Common installation locations checked (`C:\Program Files\PostgreSQL`, `C:\PostgreSQL`, `C:\Program Files (x86)\PostgreSQL`) | None found |
| PostgreSQL Windows service enumeration | Blocked: Service Control Manager access denied; installed service cannot be ruled out |
| TCP listener / loopback connection on 5432 | No listener; `127.0.0.1:5432` connection failed |
| TCP listener / loopback connection on 8080 | No listener; `127.0.0.1:8080` connection failed |
| Current process database/config environment | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `DDL_AUTO`, `SEED_DEMO_DATA`, and `SPRING_PROFILES_ACTIVE` are absent; secret values were not displayed |
| Existing database/data | Unknown. No connection was possible, so no claim is made about whether a database exists or contains data |

The existing documentation records PostgreSQL 14+ as the project requirement, but this machine's installed PostgreSQL version is not verifiable. A successful `/api/health` response would only prove application liveness; it is not a database readiness check.

## Backend configuration and startup safety

`backend/pom.xml` is a Spring Boot 4.1.1 Maven project, targets Java 21, and includes Spring MVC, Spring Data JPA, validation, and the PostgreSQL JDBC driver. The project's documented launch command is `mvn spring-boot:run` from `backend/`; tests use `mvn test`. The source configuration provides no default database credentials and does not fall back to an embedded database. Required variables are:

- `DB_URL` — JDBC URL for the already-existing PostgreSQL database, e.g. `jdbc:postgresql://localhost:5432/<verified_database>`.
- `DB_USERNAME` — an existing database role with the reviewed privileges.
- `DB_PASSWORD` — the existing role password.

`application.yml` selects the `dev` profile by default. `application-dev.yml` resolves `DDL_AUTO` to `update` and `SEED_DEMO_DATA` to `true` if those variables are absent; this profile's seeder inserts synthetic rows. Although the seeder is insert-only, it still writes data. **Do not run with these defaults against an uninspected database.**

For a non-mutating local validation startup, explicitly retain the existing local `dev` profile/CORS behavior while setting `DDL_AUTO=validate` and `SEED_DEMO_DATA=false`. With `validate`, Hibernate should reject missing or mismatched mapped schema instead of creating/updating it; validate mode is not proof of all DDL constraints or migration correctness. The backend should only be started after the target database and schema have been identified and approved. The API has no authentication; keep it local/private.

`application-prod.yml` disables seeding and forces `validate`, but enables PostgreSQL `sslmode=verify-full` and disables CORS unless exact origins are configured. It is not a shortcut for a local database without the required TLS/CA setup.

## Entity-to-schema review

Entity mappings describe the schema Hibernate expects; they do not establish what exists in the unreachable database.

| Data | Entity mapping / expected structure |
|---|---|
| Routes and stops | `Route` → `routes` (id, name, data origin, active); `Stop` → `stops` (id, name, coordinates, verification status). |
| Ordered route stops | `RouteStop` → `route_stops`, references routes/stops, with nonnegative `stop_order`, unique route/stop pair and unique `(route_id, stop_order)`; complete contiguous order is also a service-level invariant. `RouteStopId` is the embedded route/stop identity. |
| Buses | `Bus` → `buses`, references a route; unique fleet code; positive seating capacity; optional total passenger capacity no smaller than seating capacity. |
| Ticket events | `Ticket` → `tickets`, references bus and boarding/destination stops; optional string `trip_id`; positive passenger count; event timestamp and data origin; unique idempotency key; nullable unique `booking_id` reference to a passenger booking. Existing stable rows and nullable legacy trip context must be retained. |
| Passenger bookings | `PassengerBooking` → `passenger_bookings`, unique booking reference and idempotency key; required trip/bus/boarding/destination/count/status/created time; positive count; references bus and stops. The class has no `PassengerBookingEvent` entity. |
| Simulated arrivals | `SimulatedTripArrival` → `simulated_trip_arrivals`, event ID primary key; required bus/stop/trip/order/time/alighting count/data origin; intended unique arrival per trip and route order. |

`backend/db/migration/` contains SQL drafts only. `backend/pom.xml` has no Flyway or Liquibase dependency, and source inspection found no configured migration runner. No initial/core schema migration is present here; V1–V6 are not an established, automatically ordered migration history. Core tables may have been created by a past Hibernate `update` or other manual setup, but this cannot be verified.

### Draft migration review and recommendations (not applied)

- **V1 `V1__ticket_trip_context.sql`:** adds nullable `tickets.trip_id`, backfills only listed stable ticket IDs, then adds an index. It preserves other legacy rows, but its assumptions about the live `tickets` table and the exact fixture IDs must be checked against a backup and actual data before use.
- **V2 `V2__simulated_trip_arrivals.sql`:** creates the arrival table with `UNIQUE (bus_id, trip_id, stop_order)`. The entity currently declares `UNIQUE (trip_id, stop_order)` without `bus_id`. These are different keys. The project must choose whether trip IDs are globally unique or bus-scoped; the practical recommendation is to treat a trip as bus-scoped and align the entity constraint/index/query semantics and draft SQL to `(bus_id, trip_id, stop_order)`, after confirming the application invariant. Do not apply V2 until reconciled. Also review/check the nonnegative alighting constraint and stop-order semantics against entity validation.
- **V3 `V3__service_runs.sql`:** proposes a future relational service-run model and nullable ticket link. It is not mapped by a current entity and explicitly leaves trip backfill unresolved. Keep deferred until canonical trip identity, service date, timezone, and mapping are agreed.
- **V4 `V4__etm_identifier_mappings.sql` / V5 `V5__etm_event_ledger.sql`:** vendor/provider tables are drafts. Vendor formats, mapping evidence, event semantics, retention, and replay policy are unavailable. Do not create or seed synthetic vendor mappings.
- **V6 `V6__passenger_bookings.sql`:** broadly reflects `PassengerBooking` and the nullable unique ticket-to-booking relationship, including a passenger count check and supported status values. It additionally creates `passenger_booking_events`, for which no entity/repository/runtime workflow was found. Decide whether that event table is needed and implement/map its lifecycle or omit it from the eventual approved schema. Compare all column types, lengths, nullability, enum/status values, indexes, and unique constraints to the actual existing tables before adoption.

No migration should be selected or executed until the exact existing database/schema is identified, a verified backup/recovery plan exists, migration ordering/tooling is selected, and the drafts are reconciled. The reservation lifecycle currently has no cancellation/expiry state; V6's two statuses reflect that limitation.

## Safe next manual steps

First identify the installed PostgreSQL service and intended database with a Windows administrator or the machine owner; service enumeration was blocked here. Do not create a database or cluster to work around the missing visibility. Once the owner confirms an existing development database and schema, inspect it read-only and confirm a backup/recovery point before any startup that could write.

After database/schema readiness is established, open PowerShell in `backend/` and use the following template. Replace the JDBC database name and role with values verified by the owner; do not paste a password into a command or source file. This only starts the backend when you explicitly run it; this report did not run it.

```powershell
Set-Location 'C:\Users\PC\OneDrive\Desktop\safersetu\backend'
$env:SPRING_PROFILES_ACTIVE = 'dev'
$env:DB_URL = 'jdbc:postgresql://localhost:5432/<verified_existing_database>'
$env:DB_USERNAME = '<verified_existing_role>'
$secureDbPassword = Read-Host 'Existing PostgreSQL password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureDbPassword)
try {
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}
$env:DDL_AUTO = 'validate'
$env:SEED_DEMO_DATA = 'false'
mvn spring-boot:run
```

Keep the terminal open while the service runs. Startup should fail if required mapped tables/columns are absent or incompatible; stop at that point and review the error rather than switching to `update`. After startup, check process liveness with `Invoke-RestMethod http://localhost:8080/api/health`, then exercise a database-backed endpoint such as `http://localhost:8080/api/stops?page=0&size=1` to verify actual DB access. A health response alone is insufficient. Keep the backend bound to local/private access because the API is unauthenticated.

To stop only the backend started in that terminal, press **Ctrl+C** there. Then remove the temporary process environment values from that PowerShell session:

```powershell
Remove-Item Env:DB_PASSWORD, Env:DB_USERNAME, Env:DB_URL, Env:DDL_AUTO, Env:SEED_DEMO_DATA, Env:SPRING_PROFILES_ACTIVE -ErrorAction SilentlyContinue
Remove-Variable secureDbPassword, passwordPointer -ErrorAction SilentlyContinue
```

Starting/stopping the PostgreSQL Windows service, installing PostgreSQL, creating a database/role, applying migrations, or changing schema/data requires an explicit separately approved action after the installation, target database, and backup are known. No such action was taken in this phase.

## Readiness conclusion

- **PostgreSQL installation/service:** not confirmed; common paths and PATH tools were absent, service inspection was permission-blocked.
- **Existing database/data:** unknown and not inspected; no destructive or write operation was performed.
- **Backend:** not running. Safe only after an existing database/schema has been identified and the non-mutating validation settings above are used.
- **Schema:** source entities and draft migrations are reviewable, but there is no migration runner or verified target schema. V2's arrival uniqueness mismatch must be reconciled; V6's event table is currently unmapped.
- **Safest next action:** have the database owner identify the existing PostgreSQL installation/service, database name/schema, role, and recovery/backup process. Then obtain approval to inspect/start that exact service or proceed with a read-only schema check. Do not create a replacement database or run Hibernate `update`.
