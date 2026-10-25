DO $$
BEGIN
 IF to_regclass('public.scan_history') IS NOT NULL THEN
  ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS impact_material varchar(20);
 END IF;
END $$;
-- No guessed material backfill: legacy generic plastic/metal remain unclassified.
