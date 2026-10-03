-- ============================================================================
-- FINDIPRO — BULLETPROOF PRODUCTION DATA CLEANUP SCRIPT (FRESH LAUNCH WIPE)
-- ============================================================================
-- Cleans all test and dummy data across all existing FindiPro tables safely.
-- Dynamically checks table existence so it NEVER throws "relation does not exist".
-- ============================================================================

BEGIN;

-- 1. Disable triggers temporarily for clean, fast truncation
SET session_replication_role = 'replica';

-- 2. Dynamically truncate only tables that actually exist in the public schema
DO $$
DECLARE
  tbl_name text;
  tables_to_clean text[] := ARRAY[
    'messages',
    'notifications',
    'user_device_tokens',
    'reviews',
    'jobs',
    'bookings',
    'provider_services',
    'services',
    'businesses',
    'providers',
    'verification_requests',
    'provider_subscriptions',
    'feedback_requests',
    'email_otps',
    'locations',
    'profiles'
  ];
BEGIN
  FOREACH tbl_name IN ARRAY tables_to_clean LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = tbl_name
    ) THEN
      EXECUTE format('TRUNCATE TABLE public.%I CASCADE;', tbl_name);
      RAISE NOTICE 'Truncated table public.%', tbl_name;
    END IF;
  END LOOP;
END $$;

-- 3. Truncate storage objects if storage schema exists (cleans uploaded test photos)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'objects') THEN
    DELETE FROM storage.objects WHERE bucket_id IN ('avatars', 'portfolio', 'business-images', 'job-images', 'documents');
    RAISE NOTICE 'Cleaned storage objects buckets';
  END IF;
END $$;

-- 4. Re-enable triggers and normal session role
SET session_replication_role = 'origin';

COMMIT;

-- ============================================================================
-- VERIFICATION QUERY: Counts for all existing tables (all should be 0)
-- ============================================================================
DO $$
DECLARE
  r RECORD;
  cnt BIGINT;
BEGIN
  RAISE NOTICE '================ CURRENT ROW COUNTS ================';
  FOR r IN (
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public'
    ORDER BY table_name
  ) LOOP
    EXECUTE format('SELECT count(*) FROM public.%I;', r.table_name) INTO cnt;
    RAISE NOTICE 'Table public.% : % rows', r.table_name, cnt;
  END LOOP;
END $$;

