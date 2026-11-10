-- DRAFT ONLY — NOT EXECUTED. Provider schema and identifiers are unknown until vendor samples/documentation are supplied.
CREATE TABLE etm_providers (id varchar(64) PRIMARY KEY, name varchar(160) NOT NULL, enabled boolean NOT NULL DEFAULT false);
CREATE TABLE etm_devices (id varchar(64) PRIMARY KEY, provider_id varchar(64) NOT NULL REFERENCES etm_providers(id), external_device_id varchar(160) NOT NULL, enabled boolean NOT NULL DEFAULT false, UNIQUE(provider_id, external_device_id));
CREATE TABLE etm_identifier_mappings (id bigserial PRIMARY KEY, provider_id varchar(64) NOT NULL REFERENCES etm_providers(id), entity_type varchar(24) NOT NULL, external_id varchar(160) NOT NULL, internal_id varchar(64) NOT NULL, verified_at timestamptz, verified_by varchar(128), UNIQUE(provider_id, entity_type, external_id));
-- Validate target IDs and verified mapping evidence before enabling any mapping; do not seed synthetic mappings.
