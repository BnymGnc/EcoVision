DO $$
BEGIN
IF to_regclass('public.map_pins') IS NULL THEN
    RETURN;
END IF;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS provider varchar(30);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS external_id varchar(100);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS point_type varchar(20);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS weekly_schedule_json text;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS timezone varchar(50);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS source_status_raw integer;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS source_active_raw boolean;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS source_machine_status_raw integer;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS source_url varchar(500);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS dataset_version varchar(100);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS dataset_hash varchar(64);
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS snapshot_at timestamptz;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS imported_at timestamptz;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS telemetry_observed_at timestamptz;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS data_quality_flags text;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS source_material_codes_json text;
ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS raw_bins_json text;

UPDATE map_pins SET provider = 'ECOVISION' WHERE provider IS NULL;
UPDATE map_pins SET point_type = 'UNKNOWN' WHERE point_type IS NULL;
UPDATE map_pins SET timezone = 'Europe/Istanbul' WHERE timezone IS NULL;

ALTER TABLE map_pins ALTER COLUMN provider SET DEFAULT 'ECOVISION';
ALTER TABLE map_pins ALTER COLUMN provider SET NOT NULL;
ALTER TABLE map_pins ALTER COLUMN point_type SET DEFAULT 'UNKNOWN';
ALTER TABLE map_pins ALTER COLUMN point_type SET NOT NULL;
ALTER TABLE map_pins ALTER COLUMN timezone SET DEFAULT 'Europe/Istanbul';
ALTER TABLE map_pins ALTER COLUMN timezone SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_map_pins_provider_external_id
    ON map_pins(provider, external_id)
    WHERE external_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_map_pins_coordinates
    ON map_pins(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_map_pins_provider_dataset_hash
    ON map_pins(provider, dataset_hash);
END
$$;
