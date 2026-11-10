# ETM migration review — drafts only

**Status: NOT EXECUTED.** No migration tool or Flyway/Liquibase dependency is configured in the backend. The files under `backend/db/migration/` are proposals, not executable project migrations until a tool, ordering convention, and review process are adopted. The running backend was not started, so Hibernate did not alter schema either.

## Draft inventory

| Draft | Purpose | Preconditions / unresolved evidence |
|---|---|---|
| V2 `simulated_trip_arrivals` | Store simulation-only arrivals and derived expected alighting; unique bus/trip/route stop. | Confirm target table/column types and referenced keys. This corresponds to the simulation implementation, but must be reviewed before a future backend start that might apply schema changes. |
| V3 `service_runs` and nullable `tickets.service_run_id` | Introduce canonical run relation while preserving `trip_id`. | Agree service date/time zone, run identity/lifecycle and `routes.id` type. No automatic backfill. |
| V4 providers, devices, identifier mappings | Store explicit external-to-internal mappings. | Obtain real provider/device/vehicle/route/stop/run identifiers and a human verification process. No synthetic mapping seed data. |
| V5 normalized event ledger | Preserve source event identity, provenance, processing state, timestamps and optional sequence. | Obtain vendor event definitions, replay/sequence rules, privacy/retention policy and error semantics. No raw passenger PII payload included. |
| V6 passenger bookings | Keep future passenger booking and booking events separate from ETM/ticket observations. | Confirm booking, cancellation, payment, privacy and retention requirements. Bookings must not count as evidence of boarding. |

## Compatibility and safety

All drafts are additive. They do not drop or rename existing columns/tables and do not rewrite existing `tickets.trip_id` values. V3 explicitly leaves the new run reference nullable and requires verified explicit mapping before any backfill. V2's key scopes arrival uniqueness by bus and trip so equal textual trip IDs on distinct buses do not collide. Existing V1 remains untouched.

No current migration executor was found in `backend/pom.xml`; the current schema validation setting means an unreviewed new entity could make application startup fail until its approved schema exists. Do not start the backend with a database until the V2 schema is reviewed/applied through an approved process or the entity is intentionally deferred. No migration has been applied in this task.

## Rollback considerations

Before any future application, take and verify a database backup, apply in a non-production environment, and test existing ticket/occupancy APIs. For additive tables, rollback may drop only the newly introduced tables after confirming no dependent application data must be retained. V3's nullable FK can be removed independently only after confirming no rows use it. Do not roll back by deleting or rewriting existing tickets. Define ledger retention and mapping correction audit requirements before production use.

## Required review before execution

1. Select and configure one migration tool and establish migration ownership/order.
2. Compare every referenced table/key/type against a schema snapshot from the target database.
3. Verify constraints, indexes, PostgreSQL version, permissions, backup and restore.
4. Supply real ETM samples and vendor documentation; verify identity mappings with an accountable fleet owner.
5. Review privacy, security, authentication, retention, event replay, and booking policy.
6. Run migrations only after explicit approval. The current implementation task did not execute them.

## Final product completion addendum — 2026-10-26

The ATM booking model is now implemented in source. V6 remains a **draft and was not executed**; it was aligned to `PassengerBooking` with non-null trip/bus/stop/quantity/status fields, a unique idempotency key, booking reference, and the bus/trip lookup index. Bookings are `CONFIRMED_SIMULATION`, separate from ETM ticket events, and do not count as observed occupancy. The extra draft `passenger_booking_events` table is not currently mapped by the JPA model; it is reserved for a future, reviewed lifecycle design.

The code acquires the same bus-row pessimistic lock for bookings and simulated ticket ingestion, but this property has only mock/service-test evidence. No PostgreSQL process, target schema, database credentials, backup, or disposable integration database was available in this run. No Hibernate startup, schema update, migration, database read, or database write was performed. V2–V6 remain unexecuted, and the migration-runner, ordering, rollback, target-schema, backup, and explicit-approval gates above remain in force.
