-- DRAFT ONLY — NOT EXECUTED. Future canonical run model; requires business agreement on service-day/time-zone and trip identity.
-- Preserve tickets.trip_id and all existing records. Do not backfill service_run_id without verified mappings.
CREATE TABLE service_runs (
  id varchar(64) PRIMARY KEY,
  bus_id varchar(32) NOT NULL REFERENCES buses(id),
  route_id varchar(32) NOT NULL REFERENCES routes(id),
  service_date date NOT NULL,
  status varchar(24) NOT NULL,
  started_at timestamptz,
  ended_at timestamptz,
  data_origin varchar(16) NOT NULL,
  UNIQUE (bus_id, route_id, service_date, id)
);
ALTER TABLE tickets ADD COLUMN service_run_id varchar(64) NULL REFERENCES service_runs(id);
-- Confirm routes.id and enum/status conventions against the target schema before applying.
