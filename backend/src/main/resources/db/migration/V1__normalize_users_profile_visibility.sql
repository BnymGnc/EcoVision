-- PostgreSQL-compatible normalization for existing EcoVision databases.
-- Existing non-empty values are retained; only NULL or blank legacy values
-- receive the application's historical PUBLIC default.
DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_schema = 'public'
             AND table_name = 'users'
             AND column_name = 'profile_visibility'
       ) THEN
        UPDATE public.users
        SET profile_visibility = 'PUBLIC'
        WHERE profile_visibility IS NULL
           OR btrim(profile_visibility::text) = '';

        ALTER TABLE public.users
            ALTER COLUMN profile_visibility DROP DEFAULT;
        ALTER TABLE public.users
            ALTER COLUMN profile_visibility TYPE varchar(20)
            USING profile_visibility::text;
        ALTER TABLE public.users
            ALTER COLUMN profile_visibility SET DEFAULT 'PUBLIC';
        ALTER TABLE public.users
            ALTER COLUMN profile_visibility SET NOT NULL;
    END IF;
END
$$;
