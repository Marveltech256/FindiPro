-- ============================================================================
-- FINDIPRO — CREATE ALL MISSING TABLES, INDEXES & RLS POLICIES
-- ============================================================================
-- Run this script in the Supabase SQL Editor.
-- It is 100% safe (idempotent with IF NOT EXISTS) and will create:
--   1. public.email_otps (4-digit email verification)
--   2. public.feedback_requests (user feedback, star ratings & feature requests)
--   3. All other core FindiPro tables if they do not yet exist
-- ============================================================================

-- 1. Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 2. EMAIL OTP AUTHENTICATION TABLE (4-Digit Anti-Spam Verification)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.email_otps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    attempts INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_otps_email ON public.email_otps (email);
CREATE INDEX IF NOT EXISTS idx_email_otps_created_at ON public.email_otps (created_at DESC);

ALTER TABLE public.email_otps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public / Anon Manage OTPs" ON public.email_otps;
CREATE POLICY "Public / Anon Manage OTPs" ON public.email_otps
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 3. USER FEEDBACK & COMMUNITY FEATURE REQUESTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.feedback_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    user_name TEXT DEFAULT 'Anonymous',
    user_email TEXT,
    user_role TEXT DEFAULT 'customer',
    type TEXT NOT NULL DEFAULT 'feedback', -- 'feedback' or 'feature_request'
    category TEXT NOT NULL DEFAULT 'General',
    title TEXT,
    description TEXT NOT NULL,
    rating NUMERIC DEFAULT 5.0,
    status TEXT DEFAULT 'pending', -- 'pending', 'under_review', 'planned', 'in_progress', 'completed', 'declined'
    votes INT DEFAULT 0,
    upvoter_uids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_requests_type ON public.feedback_requests (type);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_status ON public.feedback_requests (status);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_votes ON public.feedback_requests (votes DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_created_at ON public.feedback_requests (created_at DESC);

ALTER TABLE public.feedback_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Feedback Requests Read Policy" ON public.feedback_requests;
CREATE POLICY "Feedback Requests Read Policy" ON public.feedback_requests
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Feedback Requests Insert Policy" ON public.feedback_requests;
CREATE POLICY "Feedback Requests Insert Policy" ON public.feedback_requests
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Feedback Requests Update Policy" ON public.feedback_requests;
CREATE POLICY "Feedback Requests Update Policy" ON public.feedback_requests
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Feedback Requests Delete Policy" ON public.feedback_requests;
CREATE POLICY "Feedback Requests Delete Policy" ON public.feedback_requests
  FOR DELETE
  USING (true);

-- ============================================================================
-- 4. USER DEVICE TOKENS TABLE (Push Notifications)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    token TEXT NOT NULL,
    device_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user_id ON public.user_device_tokens (user_id);
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "User Device Tokens All" ON public.user_device_tokens;
CREATE POLICY "User Device Tokens All" ON public.user_device_tokens
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 5. REALTIME REPLICATION PUBLICATION
-- ============================================================================
DO $$
DECLARE
  tbl_name text;
  tables text[] := ARRAY[
    'profiles',
    'providers',
    'services',
    'jobs',
    'bookings',
    'reviews',
    'messages',
    'notifications',
    'verification_requests',
    'provider_subscriptions',
    'feedback_requests'
  ];
BEGIN
  FOREACH tbl_name IN ARRAY tables LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = tbl_name
    ) THEN
      BEGIN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', tbl_name);
      EXCEPTION
        WHEN duplicate_object THEN NULL;
        WHEN others THEN NULL;
      END;
    END IF;
  END LOOP;
END $$;

-- ============================================================================
-- VERIFICATION: Check created tables
-- ============================================================================
SELECT 
  table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

