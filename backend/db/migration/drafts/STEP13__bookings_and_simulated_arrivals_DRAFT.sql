-- DRAFT ONLY — DO NOT EXECUTE without the approval and preflight in
-- docs/STEP13_DATABASE_MIGRATION_PLAN.md.
-- Target: existing safarsetu database, public schema, PostgreSQL 18.6 as reported.
-- This transactional draft preserves existing application rows. It adds nullable
-- ticket context/link columns only when absent, and intentionally does not backfill
-- either column or invent a ticket-to-booking relationship.
-- Run only via psql with ON_ERROR_STOP after reviewing the schema metadata export.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
SET LOCAL search_path = public;

-- Fail closed if this is not the reviewed database/schema baseline, if a required
-- existing table is missing, if a target table appeared since inspection, or if
-- referenced ID columns have incompatible types.
DO $preflight$
DECLARE
    required_table text;
    actual_type text;
    actual_nullable text;
BEGIN
    IF current_database() <> 'safarsetu' THEN
        RAISE EXCEPTION 'Wrong database; expected safarsetu, got %', current_database();
    END IF;

    FOREACH required_table IN ARRAY ARRAY[
        'buses', 'bus_locations', 'occupancy_snapshots', 'route_stops',
        'routes', 'stops', 'tickets'
    ] LOOP
        IF to_regclass(format('%I.%I', 'public', required_table)) IS NULL THEN
            RAISE EXCEPTION 'Expected existing public.% table is missing', required_table;
        END IF;
    END LOOP;

    IF to_regclass('public.passenger_bookings') IS NOT NULL
       OR to_regclass('public.simulated_trip_arrivals') IS NOT NULL THEN
        RAISE EXCEPTION 'A proposed target table already exists; re-export and review metadata before migration';
    END IF;

    -- The referenced entity IDs must be varchar with compatible source lengths.
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='buses' AND column_name='id'
          AND data_type='character varying' AND character_maximum_length=32) THEN
        RAISE EXCEPTION 'buses.id does not match the mapped varchar(32) key';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='stops' AND column_name='id'
          AND data_type='character varying' AND character_maximum_length=40) THEN
        RAISE EXCEPTION 'stops.id does not match the mapped varchar(40) key';
    END IF;

    -- Preserve existing trip_id values. If present, require the mapped nullable varchar(64).
    SELECT data_type, is_nullable INTO actual_type, actual_nullable
    FROM information_schema.columns
    WHERE table_schema='public' AND table_name='tickets' AND column_name='trip_id';
    IF FOUND AND (actual_type <> 'character varying' OR actual_nullable <> 'YES'
                  OR (SELECT character_maximum_length FROM information_schema.columns
                      WHERE table_schema='public' AND table_name='tickets' AND column_name='trip_id') <> 64) THEN
        RAISE EXCEPTION 'Existing tickets.trip_id is incompatible; inspect and plan a reviewed conversion';
    END IF;

    -- If booking_id already exists, do not discard or reinterpret values. It must be
    -- nullable varchar(64), have no non-null values (no booking rows exist), and no duplicates.
    SELECT data_type, is_nullable INTO actual_type, actual_nullable
    FROM information_schema.columns
    WHERE table_schema='public' AND table_name='tickets' AND column_name='booking_id';
    IF FOUND THEN
        IF actual_type <> 'character varying' OR actual_nullable <> 'YES'
           OR (SELECT character_maximum_length FROM information_schema.columns
               WHERE table_schema='public' AND table_name='tickets' AND column_name='booking_id') <> 64 THEN
            RAISE EXCEPTION 'Existing tickets.booking_id is incompatible; inspect and plan a reviewed conversion';
        END IF;
        IF EXISTS (SELECT 1 FROM public.tickets WHERE booking_id IS NOT NULL) THEN
            RAISE EXCEPTION 'tickets.booking_id contains existing values; do not invent mappings; reconcile manually before migration';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_catalog.pg_indexes
               WHERE schemaname='public' AND tablename='tickets'
                 AND indexname='idx_tickets_bus_trip_boarded_at'
                 AND position('(bus_id, trip_id, boarded_at)' IN indexdef) = 0) THEN
        RAISE EXCEPTION 'Ticket trip index name exists with a different definition; inspect metadata and revise the draft';
    END IF;
END
$preflight$;

-- Only add nullable columns if absent. Existing values in trip_id are preserved.
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS trip_id varchar(64);
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS booking_id varchar(64);
CREATE INDEX IF NOT EXISTS idx_tickets_bus_trip_boarded_at
    ON public.tickets (bus_id, trip_id, boarded_at);

CREATE TABLE public.passenger_bookings (
    id varchar(64) PRIMARY KEY,
    booking_reference varchar(64) NOT NULL UNIQUE,
    idempotency_key varchar(100) NOT NULL UNIQUE,
    trip_id varchar(64) NOT NULL,
    bus_id varchar(32) NOT NULL REFERENCES public.buses(id),
    boarding_stop_id varchar(40) NOT NULL REFERENCES public.stops(id),
    destination_stop_id varchar(40) NOT NULL REFERENCES public.stops(id),
    passenger_count integer NOT NULL CHECK (passenger_count > 0),
    status varchar(32) NOT NULL CHECK (status IN ('CONFIRMED_SIMULATION', 'BOARDING_RECORDED_SIMULATION')),
    created_at timestamptz NOT NULL
);
CREATE INDEX idx_bookings_bus_trip_created
    ON public.passenger_bookings (bus_id, trip_id, created_at);

CREATE TABLE public.simulated_trip_arrivals (
    event_id varchar(64) PRIMARY KEY,
    bus_id varchar(32) NOT NULL REFERENCES public.buses(id),
    stop_id varchar(40) NOT NULL REFERENCES public.stops(id),
    trip_id varchar(64) NOT NULL,
    stop_order integer NOT NULL CHECK (stop_order >= 0),
    arrived_at timestamptz NOT NULL,
    simulated_alighting_passengers integer NOT NULL CHECK (simulated_alighting_passengers >= 0),
    data_origin varchar(16) NOT NULL DEFAULT 'SIMULATED' CHECK (data_origin = 'SIMULATED'),
    -- Chosen bus-scoped trip identity: matches the existing repository lookup
    -- (bus_id, trip_id, stop_order) and the old V2 SQL. Update the JPA entity to match.
    CONSTRAINT uq_sim_arrival_bus_trip_order UNIQUE (bus_id, trip_id, stop_order)
);
-- The unique constraint's B-tree supports the repository's bus/trip/order lookup;
-- do not add V2's redundant identical non-unique index.

-- A booking link is optional and at most one ticket may reference each booking.
-- The preflight requires that no pre-existing values need a fabricated association.
DO $booking_constraints$
DECLARE
    ticket_booking_att smallint;
    booking_id_att smallint;
BEGIN
    SELECT attnum INTO ticket_booking_att FROM pg_catalog.pg_attribute
    WHERE attrelid='public.tickets'::regclass AND attname='booking_id' AND NOT attisdropped;
    SELECT attnum INTO booking_id_att FROM pg_catalog.pg_attribute
    WHERE attrelid='public.passenger_bookings'::regclass AND attname='id' AND NOT attisdropped;

    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
                   WHERE c.conrelid='public.tickets'::regclass AND c.contype='u'
                     AND c.conkey=ARRAY[ticket_booking_att]::smallint[]) THEN
        ALTER TABLE public.tickets ADD CONSTRAINT uq_tickets_booking_id UNIQUE (booking_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
                   WHERE c.conrelid='public.tickets'::regclass AND c.contype='f'
                     AND c.confrelid='public.passenger_bookings'::regclass
                     AND c.conkey=ARRAY[ticket_booking_att]::smallint[]
                     AND c.confkey=ARRAY[booking_id_att]::smallint[]) THEN
        ALTER TABLE public.tickets ADD CONSTRAINT fk_tickets_booking_id
            FOREIGN KEY (booking_id) REFERENCES public.passenger_bookings(id);
    END IF;
END
$booking_constraints$;

-- In-transaction postflight: fail and roll back if required objects are missing.
DO $postflight$
DECLARE
    required_column record;
BEGIN
    IF to_regclass('public.passenger_bookings') IS NULL
       OR to_regclass('public.simulated_trip_arrivals') IS NULL THEN
        RAISE EXCEPTION 'Postflight failed: required table missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='tickets' AND column_name='trip_id'
          AND data_type='character varying' AND character_maximum_length=64 AND is_nullable='YES')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='tickets' AND column_name='booking_id'
          AND data_type='character varying' AND character_maximum_length=64 AND is_nullable='YES') THEN
        RAISE EXCEPTION 'Postflight failed: ticket context/link columns are not as expected';
    END IF;
    FOR required_column IN
        SELECT * FROM (VALUES
            ('passenger_bookings','id'), ('passenger_bookings','booking_reference'),
            ('passenger_bookings','idempotency_key'), ('passenger_bookings','trip_id'),
            ('passenger_bookings','bus_id'), ('passenger_bookings','boarding_stop_id'),
            ('passenger_bookings','destination_stop_id'), ('passenger_bookings','passenger_count'),
            ('passenger_bookings','status'), ('passenger_bookings','created_at'),
            ('simulated_trip_arrivals','event_id'), ('simulated_trip_arrivals','bus_id'),
            ('simulated_trip_arrivals','stop_id'), ('simulated_trip_arrivals','trip_id'),
            ('simulated_trip_arrivals','stop_order'), ('simulated_trip_arrivals','arrived_at'),
            ('simulated_trip_arrivals','simulated_alighting_passengers'),
            ('simulated_trip_arrivals','data_origin')
        ) AS expected(table_name, column_name)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns c
                       WHERE c.table_schema='public'
                         AND c.table_name=required_column.table_name
                         AND c.column_name=required_column.column_name) THEN
            RAISE EXCEPTION 'Postflight failed: missing %.% column',
                required_column.table_name, required_column.column_name;
        END IF;
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
        JOIN pg_catalog.pg_attribute a ON a.attrelid=c.conrelid AND a.attname='booking_id' AND NOT a.attisdropped
        WHERE c.conrelid='public.tickets'::regclass AND c.contype='u'
          AND c.conkey=ARRAY[a.attnum]::smallint[])
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
        JOIN pg_catalog.pg_attribute ta ON ta.attrelid=c.conrelid AND ta.attname='booking_id' AND NOT ta.attisdropped
        JOIN pg_catalog.pg_attribute ba ON ba.attrelid=c.confrelid AND ba.attname='id' AND NOT ba.attisdropped
        WHERE c.conrelid='public.tickets'::regclass AND c.contype='f'
          AND c.confrelid='public.passenger_bookings'::regclass
          AND c.conkey=ARRAY[ta.attnum]::smallint[] AND c.confkey=ARRAY[ba.attnum]::smallint[])
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint
        WHERE conrelid='public.simulated_trip_arrivals'::regclass
          AND conname='uq_sim_arrival_bus_trip_order' AND contype='u') THEN
        RAISE EXCEPTION 'Postflight failed: expected booking/arrival constraints are absent';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_indexes
        WHERE schemaname='public' AND tablename='tickets'
          AND indexname='idx_tickets_bus_trip_boarded_at') THEN
        RAISE EXCEPTION 'Postflight failed: required ticket trip index is absent';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_indexes
        WHERE schemaname='public' AND tablename='passenger_bookings'
          AND indexname='idx_bookings_bus_trip_created') THEN
        RAISE EXCEPTION 'Postflight failed: required booking lookup index is absent';
    END IF;
END
$postflight$;

-- Metadata-only verification output; no application rows are read or modified.
SELECT table_name FROM information_schema.tables
WHERE table_schema='public'
  AND table_name IN ('buses','bus_locations','occupancy_snapshots','route_stops','routes','stops','tickets','passenger_bookings','simulated_trip_arrivals')
ORDER BY table_name;
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid, true) AS definition
FROM pg_catalog.pg_constraint
WHERE connamespace='public'::regnamespace
  AND conname IN ('fk_tickets_booking_id','uq_tickets_booking_id','uq_sim_arrival_bus_trip_order')
ORDER BY conrelid::regclass::text, conname;

-- Operator must inspect output before allowing the transaction to commit.
-- Replace this with COMMIT only after successful pre/postflight and approval;
-- on any uncertainty, issue ROLLBACK or exit psql so the open transaction rolls back.
ROLLBACK;
