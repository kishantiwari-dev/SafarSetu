-- DRAFT ONLY — NOT EXECUTED. Future passenger bookings are separate from ticket/ETM observed-event records.
-- Booking must never be interpreted as proof of boarding or used as observed occupancy.
CREATE TABLE passenger_bookings (
  id varchar(64) PRIMARY KEY,
  booking_reference varchar(64) NOT NULL UNIQUE,
  idempotency_key varchar(100) NOT NULL UNIQUE,
  trip_id varchar(64) NOT NULL,
  bus_id varchar(32) NOT NULL REFERENCES buses(id),
  boarding_stop_id varchar(40) NOT NULL REFERENCES stops(id),
  destination_stop_id varchar(40) NOT NULL REFERENCES stops(id),
  passenger_count integer NOT NULL CHECK(passenger_count > 0),
  status varchar(32) NOT NULL CHECK(status IN ('CONFIRMED_SIMULATION','BOARDING_RECORDED_SIMULATION')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_bookings_bus_trip_created ON passenger_bookings(bus_id, trip_id, created_at);
CREATE TABLE passenger_booking_events (
  id bigserial PRIMARY KEY,
  booking_id varchar(64) NOT NULL REFERENCES passenger_bookings(id),
  event_type varchar(24) NOT NULL,
  occurred_at timestamptz NOT NULL,
  idempotency_key varchar(100) NOT NULL UNIQUE
);
-- A simulated ticket event may explicitly link to its matching booking once, moving the
-- reservation state to BOARDING_RECORDED_SIMULATION without claiming physical verification.
ALTER TABLE tickets ADD COLUMN booking_id varchar(64) NULL UNIQUE REFERENCES passenger_bookings(id);
-- No cancellation, payment, expiry, or passenger identity is modeled in this simulation release.
-- Confirm the target schema and backup before adopting a migration runner or executing this draft.
