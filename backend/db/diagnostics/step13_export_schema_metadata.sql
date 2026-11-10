-- READ ONLY: schema metadata export for SafarSetu Step 13.
-- Run with psql against the already-existing safarsetu database. No rows from
-- application tables are selected. This script does not create/write objects.
BEGIN TRANSACTION READ ONLY;

-- Confirm the target table inventory (including expected new tables, if any).
WITH targets(table_name) AS (
    VALUES ('buses'), ('bus_locations'), ('occupancy_snapshots'), ('route_stops'),
           ('routes'), ('stops'), ('tickets'),
           ('passenger_bookings'), ('simulated_trip_arrivals')
)
SELECT current_database() AS database_name,
       'public' AS schema_name,
       targets.table_name,
       (to_regclass(format('%I.%I', 'public', targets.table_name)) IS NOT NULL) AS exists
FROM targets
ORDER BY targets.table_name;

-- Column type, nullability, default, identity/generated metadata, and order.
SELECT c.table_name,
       c.ordinal_position,
       c.column_name,
       c.data_type,
       c.udt_schema,
       c.udt_name,
       c.character_maximum_length,
       c.numeric_precision,
       c.numeric_scale,
       c.datetime_precision,
       c.is_nullable,
       c.column_default,
       c.is_identity,
       c.identity_generation,
       c.is_generated,
       c.generation_expression
FROM information_schema.columns AS c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
      'buses', 'bus_locations', 'occupancy_snapshots', 'route_stops',
      'routes', 'stops', 'tickets', 'passenger_bookings', 'simulated_trip_arrivals'
  )
ORDER BY c.table_name, c.ordinal_position;

-- Primary keys, unique constraints, foreign keys, and check constraints.
SELECT n.nspname AS schema_name,
       t.relname AS table_name,
       con.conname AS constraint_name,
       CASE con.contype
           WHEN 'p' THEN 'PRIMARY KEY'
           WHEN 'u' THEN 'UNIQUE'
           WHEN 'f' THEN 'FOREIGN KEY'
           WHEN 'c' THEN 'CHECK'
           WHEN 'x' THEN 'EXCLUSION'
           ELSE con.contype::text
       END AS constraint_type,
       pg_get_constraintdef(con.oid, true) AS definition,
       con.convalidated AS validated
FROM pg_catalog.pg_constraint AS con
JOIN pg_catalog.pg_class AS t ON t.oid = con.conrelid
JOIN pg_catalog.pg_namespace AS n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relname IN (
      'buses', 'bus_locations', 'occupancy_snapshots', 'route_stops',
      'routes', 'stops', 'tickets', 'passenger_bookings', 'simulated_trip_arrivals'
  )
ORDER BY t.relname, constraint_type, con.conname;

-- Index definitions, including unique/partial indexes and included columns.
SELECT schemaname AS schema_name,
       tablename AS table_name,
       indexname AS index_name,
       indexdef AS definition
FROM pg_catalog.pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'buses', 'bus_locations', 'occupancy_snapshots', 'route_stops',
      'routes', 'stops', 'tickets', 'passenger_bookings', 'simulated_trip_arrivals'
  )
ORDER BY tablename, indexname;

COMMIT;
