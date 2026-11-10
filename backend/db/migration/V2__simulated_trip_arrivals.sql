-- DRAFT ONLY — NOT EXECUTED. No migration runner is configured in this project.
-- Additive simulated event storage; no existing ticket, trip, route, or bus rows are rewritten.
CREATE TABLE simulated_trip_arrivals (
  event_id varchar(64) PRIMARY KEY,
  bus_id varchar(32) NOT NULL REFERENCES buses(id),
  stop_id varchar(40) NOT NULL REFERENCES stops(id),
  trip_id varchar(64) NOT NULL,
  stop_order integer NOT NULL CHECK (stop_order >= 0),
  arrived_at timestamptz NOT NULL,
  simulated_alighting_passengers integer NOT NULL CHECK (simulated_alighting_passengers >= 0),
  data_origin varchar(16) NOT NULL DEFAULT 'SIMULATED' CHECK (data_origin = 'SIMULATED'),
  CONSTRAINT uq_sim_arrival_trip_order UNIQUE (bus_id, trip_id, stop_order)
);
CREATE INDEX idx_sim_arrival_bus_trip_order ON simulated_trip_arrivals(bus_id, trip_id, stop_order);
-- Before application, verify referenced buses/stops and apply only after backup/review.
