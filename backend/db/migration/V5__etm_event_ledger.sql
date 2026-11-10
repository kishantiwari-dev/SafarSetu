-- DRAFT ONLY — NOT EXECUTED. Normalized provenance ledger; payload retention/privacy and provider event semantics remain unresolved.
CREATE TABLE etm_event_ledger (
  id bigserial PRIMARY KEY,
  provider_id varchar(64) NOT NULL REFERENCES etm_providers(id),
  device_id varchar(64) REFERENCES etm_devices(id),
  source_event_id varchar(160) NOT NULL,
  event_type varchar(32) NOT NULL,
  source_occurred_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  sequence_number bigint,
  processing_status varchar(24) NOT NULL,
  error_code varchar(64),
  content_hash varchar(128),
  bus_id varchar(32) REFERENCES buses(id),
  trip_id varchar(64),
  stop_id varchar(40) REFERENCES stops(id),
  UNIQUE(provider_id, source_event_id)
);
-- Do not store raw passenger PII here. Define retention, replay and sequence semantics from vendor evidence first.
