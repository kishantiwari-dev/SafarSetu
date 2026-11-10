-- Non-destructive trip-context addition for existing PostgreSQL databases.
-- Safe to rerun: it adds the nullable column only when absent and backfills only
-- the known stable simulated fixture IDs that still have no trip assignment.
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS trip_id varchar(64);

UPDATE tickets
SET trip_id = 'SIM-TRIP-' || bus_id || '-DEMO-01'
WHERE trip_id IS NULL
  AND id IN (
    'T-SIM-001', 'T-SIM-002', 'T-SIM-003', 'T-SIM-004', 'T-SIM-005', 'T-SIM-006',
    'T-SIM-007', 'T-SIM-008', 'T-SIM-009', 'T-SIM-010', 'T-SIM-011', 'T-SIM-012',
    'T-SIM-013', 'T-SIM-014', 'T-SIM-015', 'T-SIM-016', 'T-SIM-017', 'T-SIM-018'
  );

CREATE INDEX IF NOT EXISTS idx_tickets_bus_trip_boarded_at
    ON tickets (bus_id, trip_id, boarded_at);
