-- Hibernate 6/PostgreSQL does not support embedding DEFAULT in ALTER COLUMN
-- TYPE statements. Keep database defaults with PostgreSQL's standalone,
-- valid syntax while Java field initializers preserve fresh-schema behavior.
DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'users'
             AND column_name = 'selected_avatar_path'
       ) THEN
        UPDATE public.users
        SET selected_avatar_path = 'assets/images/avatars/avatar_level_1.png'
        WHERE selected_avatar_path IS NULL OR btrim(selected_avatar_path) = '';
        ALTER TABLE public.users
            ALTER COLUMN selected_avatar_path
            SET DEFAULT 'assets/images/avatars/avatar_level_1.png';
    END IF;

    IF to_regclass('public.users') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'users'
             AND column_name = 'theme_preference'
       ) THEN
        UPDATE public.users
        SET theme_preference = 'forest'
        WHERE theme_preference IS NULL OR btrim(theme_preference) = '';
        ALTER TABLE public.users
            ALTER COLUMN theme_preference SET DEFAULT 'forest';
    END IF;

    IF to_regclass('public.users') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'users'
             AND column_name = 'banned'
       ) THEN
        ALTER TABLE public.users
            ALTER COLUMN banned SET DEFAULT false;
    END IF;

    IF to_regclass('public.users') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'users'
             AND column_name = 'failed_login_attempts'
       ) THEN
        UPDATE public.users
        SET failed_login_attempts = 0
        WHERE failed_login_attempts IS NULL;
        ALTER TABLE public.users
            ALTER COLUMN failed_login_attempts SET DEFAULT 0;
    END IF;

    IF to_regclass('public.chat_messages') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'chat_messages'
             AND column_name = 'deleted'
       ) THEN
        UPDATE public.chat_messages SET deleted = false WHERE deleted IS NULL;
        ALTER TABLE public.chat_messages
            ALTER COLUMN deleted SET DEFAULT false;
    END IF;

    IF to_regclass('public.chat_messages') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'chat_messages'
             AND column_name = 'message_type'
       ) THEN
        UPDATE public.chat_messages
        SET message_type = 'USER'
        WHERE message_type IS NULL OR btrim(message_type::text) = '';
        ALTER TABLE public.chat_messages
            ALTER COLUMN message_type SET DEFAULT 'USER';
    END IF;

    IF to_regclass('public.community_groups') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'community_groups'
             AND column_name = 'private_group'
       ) THEN
        UPDATE public.community_groups
        SET private_group = false
        WHERE private_group IS NULL;
        ALTER TABLE public.community_groups
            ALTER COLUMN private_group SET DEFAULT false;
    END IF;
END
$$;
