CREATE TABLE IF NOT EXISTS revoked_access_tokens (
 token_hash varchar(64) PRIMARY KEY, expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_revoked_access_expiry ON revoked_access_tokens(expires_at);
DO $$
BEGIN
 IF to_regclass('public.media_assets') IS NOT NULL THEN
  ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS owner_user_id bigint;
  CREATE INDEX IF NOT EXISTS idx_media_owner ON media_assets(owner_user_id);
 END IF;
 IF to_regclass('public.scan_history') IS NOT NULL THEN
  ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS analysis_id uuid;
  ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS image_hash varchar(64);
  ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS reward_date date;
  ALTER TABLE scan_history ADD COLUMN IF NOT EXISTS reward_status varchar(30);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_scan_analysis ON scan_history(analysis_id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_scan_image_reward ON scan_history(user_id,image_hash,reward_date)
   WHERE image_hash IS NOT NULL AND points_awarded > 0;
 END IF;
END $$;
