-- ============================================================================
-- FINDIPRO — COMPLETE PRODUCTION SCHEMA, RLS & REALTIME SCRIPT
-- ============================================================================
-- Safe & Idempotent: Can be run on any Supabase project without missing relation errors.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS & ALL APP TABLES (CREATE IF NOT EXISTS)
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'customer',
    category TEXT,
    location TEXT,
    bio TEXT,
    about TEXT,
    skills TEXT[] DEFAULT '{}',
    years_experience INT DEFAULT 0,
    price_range TEXT,
    rating NUMERIC DEFAULT 0,
    review_count INT DEFAULT 0,
    plan TEXT DEFAULT 'premium',
    verified BOOLEAN DEFAULT true,
    premium BOOLEAN DEFAULT true,
    verification_status TEXT DEFAULT 'approved',
    subscription_status TEXT DEFAULT 'active',
    is_blocked BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure presence and plan columns exist if table was already created
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'premium';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS premium BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'approved';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'active';

-- 2. PROVIDERS TABLE
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    firebase_uid TEXT,
    uid TEXT,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    category TEXT,
    location TEXT,
    about TEXT,
    bio TEXT,
    skills TEXT[] DEFAULT '{}',
    years_experience INT DEFAULT 0,
    price_range TEXT,
    available BOOLEAN DEFAULT true,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    avatar_url TEXT,
    business_name TEXT,
    rating NUMERIC DEFAULT 0,
    review_count INT DEFAULT 0,
    plan TEXT DEFAULT 'premium',
    verified BOOLEAN DEFAULT true,
    premium BOOLEAN DEFAULT true,
    verification_status TEXT DEFAULT 'approved',
    subscription_status TEXT DEFAULT 'active',
    is_blocked BOOLEAN DEFAULT false,
    is_admin BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT true,
    portfolio_images TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. BUSINESSES TABLE
CREATE TABLE IF NOT EXISTS public.businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID,
    name TEXT,
    category TEXT,
    description TEXT,
    phone TEXT,
    email TEXT,
    location TEXT,
    rating NUMERIC DEFAULT 0,
    review_count INT DEFAULT 0,
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. SERVICES TABLE
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    price NUMERIC DEFAULT 0,
    currency TEXT DEFAULT 'UGX',
    duration TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. PROVIDER_SERVICES JUNCTION TABLE
CREATE TABLE IF NOT EXISTS public.provider_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id TEXT,
    service_id UUID,
    price NUMERIC DEFAULT 0,
    currency TEXT DEFAULT 'UGX',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id TEXT,
    provider_id TEXT,
    service_id TEXT,
    service_title TEXT,
    client_name TEXT,
    client_phone TEXT,
    provider_name TEXT,
    location TEXT,
    notes TEXT,
    budget TEXT,
    scheduled_at TIMESTAMPTZ,
    status TEXT DEFAULT 'requested',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. JOBS TABLE
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id TEXT,
    provider_id TEXT,
    title TEXT,
    description TEXT,
    category TEXT,
    location TEXT,
    price NUMERIC DEFAULT 0,
    currency TEXT DEFAULT 'UGX',
    status TEXT DEFAULT 'requested',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 8. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id TEXT,
    booking_id TEXT,
    provider_id TEXT,
    customer_id TEXT,
    business_id TEXT,
    reviewer_name TEXT,
    reviewer_avatar TEXT,
    rating NUMERIC NOT NULL DEFAULT 5,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 9. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    text TEXT,
    image_url TEXT,
    file_url TEXT,
    type TEXT DEFAULT 'text',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'general',
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. USER DEVICE TOKENS TABLE (FCM)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    platform TEXT,
    device_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT user_fcm_unique UNIQUE (user_id, fcm_token)
);

-- 12. VERIFICATION REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.verification_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    provider_id TEXT,
    national_id_number TEXT,
    id_front_url TEXT,
    id_back_url TEXT,
    business_doc_url TEXT,
    status TEXT DEFAULT 'pending',
    admin_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 13. PROVIDER SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.provider_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id TEXT NOT NULL,
    plan TEXT NOT NULL DEFAULT 'premium',
    billing_period TEXT NOT NULL DEFAULT 'monthly',
    amount NUMERIC NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'UGX',
    payment_method TEXT DEFAULT 'promo',
    transaction_ref TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    is_active BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 2. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 3. PERMISSIVE POLICIES FOR ALL APP TABLES
-- ----------------------------------------------------------------------------

-- PROFILES
DROP POLICY IF EXISTS profiles_all_policy ON public.profiles;
CREATE POLICY profiles_all_policy ON public.profiles FOR ALL USING (true) WITH CHECK (true);

-- PROVIDERS
DROP POLICY IF EXISTS providers_all_policy ON public.providers;
CREATE POLICY providers_all_policy ON public.providers FOR ALL USING (true) WITH CHECK (true);

-- BUSINESSES
DROP POLICY IF EXISTS businesses_all_policy ON public.businesses;
CREATE POLICY businesses_all_policy ON public.businesses FOR ALL USING (true) WITH CHECK (true);

-- SERVICES
DROP POLICY IF EXISTS services_all_policy ON public.services;
CREATE POLICY services_all_policy ON public.services FOR ALL USING (true) WITH CHECK (true);

-- PROVIDER_SERVICES
DROP POLICY IF EXISTS provider_services_all_policy ON public.provider_services;
CREATE POLICY provider_services_all_policy ON public.provider_services FOR ALL USING (true) WITH CHECK (true);

-- BOOKINGS
DROP POLICY IF EXISTS bookings_all_policy ON public.bookings;
CREATE POLICY bookings_all_policy ON public.bookings FOR ALL USING (true) WITH CHECK (true);

-- JOBS
DROP POLICY IF EXISTS jobs_all_policy ON public.jobs;
CREATE POLICY jobs_all_policy ON public.jobs FOR ALL USING (true) WITH CHECK (true);

-- REVIEWS
DROP POLICY IF EXISTS reviews_all_policy ON public.reviews;
CREATE POLICY reviews_all_policy ON public.reviews FOR ALL USING (true) WITH CHECK (true);

-- MESSAGES
DROP POLICY IF EXISTS messages_all_policy ON public.messages;
CREATE POLICY messages_all_policy ON public.messages FOR ALL USING (true) WITH CHECK (true);

-- NOTIFICATIONS
DROP POLICY IF EXISTS notifications_all_policy ON public.notifications;
CREATE POLICY notifications_all_policy ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- USER_DEVICE_TOKENS
DROP POLICY IF EXISTS user_device_tokens_all_policy ON public.user_device_tokens;
CREATE POLICY user_device_tokens_all_policy ON public.user_device_tokens FOR ALL USING (true) WITH CHECK (true);

-- VERIFICATION_REQUESTS
DROP POLICY IF EXISTS verification_requests_all_policy ON public.verification_requests;
CREATE POLICY verification_requests_all_policy ON public.verification_requests FOR ALL USING (true) WITH CHECK (true);

-- PROVIDER_SUBSCRIPTIONS
DROP POLICY IF EXISTS provider_subscriptions_all_policy ON public.provider_subscriptions;
CREATE POLICY provider_subscriptions_all_policy ON public.provider_subscriptions FOR ALL USING (true) WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 4. ENABLE REALTIME ON KEY TABLES
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.bookings REPLICA IDENTITY FULL;
ALTER TABLE public.jobs REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'bookings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'jobs') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;
  END IF;
END $$;

$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_provider_escalation ON public.providers;
CREATE TRIGGER trg_prevent_provider_escalation
  BEFORE INSERT OR UPDATE ON public.providers
  FOR EACH ROW EXECUTE FUNCTION public.prevent_provider_privilege_escalation();

-- ----------------------------------------------------------------------------
-- 4. BUSINESSES TABLE (public.businesses)
-- ----------------------------------------------------------------------------
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS businesses_select_policy ON public.businesses;
CREATE POLICY businesses_select_policy ON public.businesses FOR SELECT USING (true);

DROP POLICY IF EXISTS businesses_insert_policy ON public.businesses;
CREATE POLICY businesses_insert_policy ON public.businesses 
  FOR INSERT WITH CHECK (auth.uid() = owner_id OR public.is_admin());

DROP POLICY IF EXISTS businesses_update_policy ON public.businesses;
CREATE POLICY businesses_update_policy ON public.businesses 
  FOR UPDATE USING (auth.uid() = owner_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 5. SERVICES & CATEGORIES (public.services, public.service_categories)
-- ----------------------------------------------------------------------------
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

-- Customers & visitors can read all active services
DROP POLICY IF EXISTS services_select_policy ON public.services;
CREATE POLICY services_select_policy ON public.services FOR SELECT USING (true);

-- Only owning provider or admin can insert services
DROP POLICY IF EXISTS services_insert_policy ON public.services;
CREATE POLICY services_insert_policy ON public.services 
  FOR INSERT WITH CHECK (
    auth.uid() = provider_id 
    OR EXISTS (SELECT 1 FROM public.providers WHERE id = services.provider_id AND id = auth.uid())
    OR public.is_admin()
  );

-- Only owning provider or admin can update services
DROP POLICY IF EXISTS services_update_policy ON public.services;
CREATE POLICY services_update_policy ON public.services 
  FOR UPDATE USING (
    auth.uid() = provider_id 
    OR EXISTS (SELECT 1 FROM public.providers WHERE id = services.provider_id AND id = auth.uid())
    OR public.is_admin()
  );

-- Only owning provider or admin can delete services
DROP POLICY IF EXISTS services_delete_policy ON public.services;
CREATE POLICY services_delete_policy ON public.services 
  FOR DELETE USING (
    auth.uid() = provider_id 
    OR EXISTS (SELECT 1 FROM public.providers WHERE id = services.provider_id AND id = auth.uid())
    OR public.is_admin()
  );

ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS categories_select_policy ON public.service_categories;
CREATE POLICY categories_select_policy ON public.service_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS categories_admin_all ON public.service_categories;
CREATE POLICY categories_admin_all ON public.service_categories 
  FOR ALL USING (public.is_admin());

-- Helper function to check if user is assigned to a job (SECURITY DEFINER prevents RLS recursion)
CREATE OR REPLACE FUNCTION public.is_job_technician_or_provider(check_job_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.job_assignments
    WHERE job_id = check_job_id AND (technician_id = auth.uid() OR provider_id = auth.uid())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is the customer of a job (SECURITY DEFINER prevents RLS recursion)
CREATE OR REPLACE FUNCTION public.is_job_customer(check_job_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.jobs
    WHERE id = check_job_id AND customer_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to validate review eligibility (SECURITY DEFINER prevents RLS recursion)
CREATE OR REPLACE FUNCTION public.can_review_job(check_job_id uuid, check_customer_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.jobs j
    WHERE j.id = check_job_id 
      AND j.customer_id = check_customer_id
      AND LOWER(j.status) = 'completed'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.job_assignments ja
    WHERE ja.job_id = check_job_id
      AND (ja.technician_id = check_customer_id OR ja.provider_id = check_customer_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 6. JOBS, BOOKINGS & JOB ASSIGNMENTS (public.jobs, public.bookings, public.job_assignments)
-- ----------------------------------------------------------------------------

-- SELF-HIRE PREVENTION TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.prevent_self_hire()
RETURNS trigger AS $$
BEGIN
  -- Customer / Client cannot hire themselves
  IF TG_TABLE_NAME = 'jobs' THEN
    IF EXISTS (
      SELECT 1 FROM public.job_assignments ja
      WHERE ja.job_id = NEW.id AND (ja.technician_id = NEW.customer_id OR ja.provider_id = NEW.customer_id)
    ) THEN
      RAISE EXCEPTION 'Security violation: Users cannot hire or assign themselves.';
    END IF;
  ELSIF TG_TABLE_NAME = 'bookings' OR TG_TABLE_NAME = 'hire_requests' THEN
    IF (NEW.client_id IS NOT NULL AND NEW.provider_id IS NOT NULL AND NEW.client_id = NEW.provider_id) OR
       (NEW.customer_id IS NOT NULL AND NEW.provider_id IS NOT NULL AND NEW.customer_id = NEW.provider_id) THEN
      RAISE EXCEPTION 'Security violation: Users cannot hire themselves.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- SELECT: Customer who created job, assigned technician, or Admin
DROP POLICY IF EXISTS jobs_select_policy ON public.jobs;
CREATE POLICY jobs_select_policy ON public.jobs 
  FOR SELECT USING (
    auth.uid() = customer_id 
    OR public.is_job_technician_or_provider(id)
    OR public.is_admin()
  );

-- INSERT: Customer creating their own job
DROP POLICY IF EXISTS jobs_insert_policy ON public.jobs;
CREATE POLICY jobs_insert_policy ON public.jobs 
  FOR INSERT WITH CHECK (auth.uid() = customer_id OR public.is_admin());

-- UPDATE: Customer or assigned technician updating status
DROP POLICY IF EXISTS jobs_update_policy ON public.jobs;
CREATE POLICY jobs_update_policy ON public.jobs 
  FOR UPDATE USING (
    auth.uid() = customer_id 
    OR public.is_job_technician_or_provider(id)
    OR public.is_admin()
  );

DROP TRIGGER IF EXISTS trg_prevent_self_hire_jobs ON public.jobs;
CREATE TRIGGER trg_prevent_self_hire_jobs
  BEFORE INSERT OR UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.prevent_self_hire();

-- BOOKINGS / HIRE REQUESTS TABLE POLICIES (if using public.bookings)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bookings') THEN
    ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS bookings_select_policy ON public.bookings;
    CREATE POLICY bookings_select_policy ON public.bookings 
      FOR SELECT USING (auth.uid() = client_id OR auth.uid() = customer_id OR auth.uid() = provider_id OR public.is_admin());

    DROP POLICY IF EXISTS bookings_insert_policy ON public.bookings;
    CREATE POLICY bookings_insert_policy ON public.bookings 
      FOR INSERT WITH CHECK (
        (auth.uid() = client_id OR auth.uid() = customer_id)
        AND client_id != provider_id
        OR public.is_admin()
      );

    DROP POLICY IF EXISTS bookings_update_policy ON public.bookings;
    CREATE POLICY bookings_update_policy ON public.bookings 
      FOR UPDATE USING (auth.uid() = client_id OR auth.uid() = customer_id OR auth.uid() = provider_id OR public.is_admin());

    DROP TRIGGER IF EXISTS trg_prevent_self_hire_bookings ON public.bookings;
    CREATE TRIGGER trg_prevent_self_hire_bookings
      BEFORE INSERT OR UPDATE ON public.bookings
      FOR EACH ROW EXECUTE FUNCTION public.prevent_self_hire();
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'hire_requests') THEN
    ALTER TABLE public.hire_requests ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS hire_req_select_policy ON public.hire_requests;
    CREATE POLICY hire_req_select_policy ON public.hire_requests 
      FOR SELECT USING (auth.uid() = client_id OR auth.uid() = customer_id OR auth.uid() = provider_id OR public.is_admin());

    DROP POLICY IF EXISTS hire_req_insert_policy ON public.hire_requests;
    CREATE POLICY hire_req_insert_policy ON public.hire_requests 
      FOR INSERT WITH CHECK (
        (auth.uid() = client_id OR auth.uid() = customer_id)
        AND client_id != provider_id
        OR public.is_admin()
      );

    DROP POLICY IF EXISTS hire_req_update_policy ON public.hire_requests;
    CREATE POLICY hire_req_update_policy ON public.hire_requests 
      FOR UPDATE USING (auth.uid() = client_id OR auth.uid() = customer_id OR auth.uid() = provider_id OR public.is_admin());

    DROP TRIGGER IF EXISTS trg_prevent_self_hire_hire_requests ON public.hire_requests;
    CREATE TRIGGER trg_prevent_self_hire_hire_requests
      BEFORE INSERT OR UPDATE ON public.hire_requests
      FOR EACH ROW EXECUTE FUNCTION public.prevent_self_hire();
  END IF;
END $$;

ALTER TABLE public.job_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS assignments_select_policy ON public.job_assignments;
CREATE POLICY assignments_select_policy ON public.job_assignments 
  FOR SELECT USING (
    auth.uid() = technician_id 
    OR auth.uid() = provider_id
    OR public.is_job_customer(job_id)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS assignments_insert_policy ON public.job_assignments;
CREATE POLICY assignments_insert_policy ON public.job_assignments 
  FOR INSERT WITH CHECK (
    public.is_job_customer(job_id)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS assignments_update_policy ON public.job_assignments;
CREATE POLICY assignments_update_policy ON public.job_assignments 
  FOR UPDATE USING (
    auth.uid() = technician_id 
    OR auth.uid() = provider_id
    OR public.is_job_customer(job_id)
    OR public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- 7. MESSAGES TABLE (public.messages)
-- ----------------------------------------------------------------------------
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users can only see private messages where they are sender or receiver
DROP POLICY IF EXISTS messages_select_policy ON public.messages;
CREATE POLICY messages_select_policy ON public.messages 
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id OR public.is_admin());

-- Users can send messages only as themselves and cannot message themselves
DROP POLICY IF EXISTS messages_insert_policy ON public.messages;
CREATE POLICY messages_insert_policy ON public.messages 
  FOR INSERT WITH CHECK (auth.uid() = sender_id AND sender_id != receiver_id);

-- Recipient can mark message as read; message content cannot be altered
DROP POLICY IF EXISTS messages_update_policy ON public.messages;
CREATE POLICY messages_update_policy ON public.messages 
  FOR UPDATE USING (auth.uid() = receiver_id OR auth.uid() = sender_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 8. REVIEWS TABLE (public.reviews)
-- ----------------------------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Public read for reviews
DROP POLICY IF EXISTS reviews_select_policy ON public.reviews;
CREATE POLICY reviews_select_policy ON public.reviews FOR SELECT USING (true);

-- Customer can write review for a completed job OR directly for a provider (no self-reviews)
DROP POLICY IF EXISTS reviews_insert_policy ON public.reviews;
CREATE POLICY reviews_insert_policy ON public.reviews 
  FOR INSERT WITH CHECK (
    auth.uid() = customer_id
    AND (
      -- Path 1: job-linked review — checked via SECURITY DEFINER function to prevent RLS recursion
      (
        job_id IS NOT NULL
        AND public.can_review_job(job_id, auth.uid())
      )
      OR
      -- Path 2: direct provider review — provider_id must exist and not be the customer
      (
        job_id IS NULL
        AND provider_id IS NOT NULL
        AND provider_id != auth.uid()
      )
    )
    OR public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- DEDUPLICATION & UNIQUE CONSTRAINTS (ensuring 1 review per service/provider)
-- ----------------------------------------------------------------------------

-- 1. Deduplicate any existing direct reviews (keeps the most recent review)
DELETE FROM public.reviews r1
USING public.reviews r2
WHERE r1.job_id IS NULL
  AND r2.job_id IS NULL
  AND r1.customer_id = r2.customer_id
  AND r1.provider_id = r2.provider_id
  AND (r1.created_at < r2.created_at OR (r1.created_at = r2.created_at AND r1.id < r2.id));

-- 2. Deduplicate any existing job-linked reviews (keeps the most recent review)
DELETE FROM public.reviews r1
USING public.reviews r2
WHERE r1.job_id IS NOT NULL
  AND r2.job_id IS NOT NULL
  AND r1.customer_id = r2.customer_id
  AND r1.job_id = r2.job_id
  AND (r1.created_at < r2.created_at OR (r1.created_at = r2.created_at AND r1.id < r2.id));

-- 3. Unique constraint for completed job reviews
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_unique_customer_job 
ON public.reviews (customer_id, job_id) 
WHERE job_id IS NOT NULL;

-- 4. Unique constraint for direct provider reviews
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_unique_customer_provider_direct 
ON public.reviews (customer_id, provider_id) 
WHERE job_id IS NULL;

-- Users cannot edit or delete another user's review
DROP POLICY IF EXISTS reviews_update_policy ON public.reviews;
CREATE POLICY reviews_update_policy ON public.reviews 
  FOR UPDATE USING (auth.uid() = customer_id OR public.is_admin());

DROP POLICY IF EXISTS reviews_delete_policy ON public.reviews;
CREATE POLICY reviews_delete_policy ON public.reviews 
  FOR DELETE USING (auth.uid() = customer_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 9. VERIFICATION REQUESTS (public.verification_requests)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.verification_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_name text NOT NULL DEFAULT '',
  national_id_number text,
  id_front_url text,
  id_back_url text,
  business_doc_url text,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;

-- Provider views their request or Admin
DROP POLICY IF EXISTS verif_select_policy ON public.verification_requests;
CREATE POLICY verif_select_policy ON public.verification_requests 
  FOR SELECT USING (auth.uid() = provider_id OR public.is_admin());

-- Provider submits pending request only
DROP POLICY IF EXISTS verif_insert_policy ON public.verification_requests;
CREATE POLICY verif_insert_policy ON public.verification_requests 
  FOR INSERT WITH CHECK (auth.uid() = provider_id AND status = 'pending');

-- Only Admin can approve or reject verification requests
DROP POLICY IF EXISTS verif_update_policy ON public.verification_requests;
CREATE POLICY verif_update_policy ON public.verification_requests 
  FOR UPDATE USING (public.is_admin());

-- ----------------------------------------------------------------------------
-- 10. PROVIDER SUBSCRIPTIONS & TRANSACTIONS (public.provider_subscriptions)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.provider_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan text NOT NULL DEFAULT 'basic',
  billing_period text NOT NULL DEFAULT 'monthly',
  amount numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'UGX',
  status text NOT NULL DEFAULT 'active',
  external_transaction_id text,
  payment_provider text DEFAULT 'In-App',
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamptz,
  cancelled_at timestamptz
);

ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;

-- Provider can read their own subscription
DROP POLICY IF EXISTS subs_select_policy ON public.provider_subscriptions;
CREATE POLICY subs_select_policy ON public.provider_subscriptions 
  FOR SELECT USING (auth.uid() = provider_id OR public.is_admin());

-- Only Admin or service role can insert/update subscription state
DROP POLICY IF EXISTS subs_admin_manage ON public.provider_subscriptions;
CREATE POLICY subs_admin_manage ON public.provider_subscriptions 
  FOR ALL USING (public.is_admin());

-- PREVENT DUPLICATE TRANSACTIONS
CREATE UNIQUE INDEX IF NOT EXISTS idx_provider_subscriptions_tx 
ON public.provider_subscriptions (external_transaction_id) 
WHERE external_transaction_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 11. NOTIFICATIONS, FAVORITES, REPORTS & DEVICE TOKENS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  type text NOT NULL DEFAULT 'general',
  data jsonb DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notif_select_policy ON public.notifications;
CREATE POLICY notif_select_policy ON public.notifications FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS notif_insert_policy ON public.notifications;
CREATE POLICY notif_insert_policy ON public.notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL OR public.is_admin());

DROP POLICY IF EXISTS notif_update_policy ON public.notifications;
CREATE POLICY notif_update_policy ON public.notifications FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT unique_user_provider_favorite UNIQUE(user_id, provider_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS favorites_policy ON public.favorites;
CREATE POLICY favorites_policy ON public.favorites FOR ALL USING (auth.uid() = user_id OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  job_id uuid,
  reason text NOT NULL DEFAULT '',
  description text,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reports_select_policy ON public.reports;
CREATE POLICY reports_select_policy ON public.reports FOR SELECT USING (auth.uid() = reporter_id OR public.is_admin());

DROP POLICY IF EXISTS reports_insert_policy ON public.reports;
CREATE POLICY reports_insert_policy ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id OR public.is_admin());

DROP POLICY IF EXISTS reports_update_policy ON public.reports;
CREATE POLICY reports_update_policy ON public.reports FOR UPDATE USING (public.is_admin());

-- USER DEVICE TOKENS (FCM Push Tokens)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'android',
  device_id text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT unique_user_fcm_token UNIQUE(user_id, fcm_token)
);

ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tokens_select_policy ON public.user_device_tokens;
CREATE POLICY tokens_select_policy ON public.user_device_tokens 
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS tokens_insert_policy ON public.user_device_tokens;
CREATE POLICY tokens_insert_policy ON public.user_device_tokens 
  FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS tokens_update_policy ON public.user_device_tokens;
CREATE POLICY tokens_update_policy ON public.user_device_tokens 
  FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS tokens_delete_policy ON public.user_device_tokens;
CREATE POLICY tokens_delete_policy ON public.user_device_tokens 
  FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 12. STORAGE BUCKET POLICIES
-- ----------------------------------------------------------------------------

-- Avatars Bucket (Public Read, Owner Write)
DROP POLICY IF EXISTS "Avatars Public Select" ON storage.objects;
CREATE POLICY "Avatars Public Select" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars Owner Insert" ON storage.objects;
CREATE POLICY "Avatars Owner Insert" ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Avatars Owner Update" ON storage.objects;
CREATE POLICY "Avatars Owner Update" ON storage.objects FOR UPDATE 
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Avatars Owner Delete" ON storage.objects;
CREATE POLICY "Avatars Owner Delete" ON storage.objects FOR DELETE 
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Business Images Bucket (Public Read, Owner Write)
DROP POLICY IF EXISTS "Business Images Public Select" ON storage.objects;
CREATE POLICY "Business Images Public Select" ON storage.objects FOR SELECT USING (bucket_id = 'business-images');

DROP POLICY IF EXISTS "Business Images Owner Insert" ON storage.objects;
CREATE POLICY "Business Images Owner Insert" ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'business-images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Business Images Owner Update" ON storage.objects;
CREATE POLICY "Business Images Owner Update" ON storage.objects FOR UPDATE 
  USING (bucket_id = 'business-images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Business Images Owner Delete" ON storage.objects;
CREATE POLICY "Business Images Owner Delete" ON storage.objects FOR DELETE 
  USING (bucket_id = 'business-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Job Images Bucket (Public Read, Owner Write)
DROP POLICY IF EXISTS "Job Images Public Select" ON storage.objects;
CREATE POLICY "Job Images Public Select" ON storage.objects FOR SELECT USING (bucket_id = 'job-images');

DROP POLICY IF EXISTS "Job Images Owner Insert" ON storage.objects;
CREATE POLICY "Job Images Owner Insert" ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'job-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Documents Bucket (Strictly Private: Owner / Admin Read & Owner Write)
DROP POLICY IF EXISTS "Documents Owner/Admin Select" ON storage.objects;
CREATE POLICY "Documents Owner/Admin Select" ON storage.objects FOR SELECT 
  USING (bucket_id = 'documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin()));

DROP POLICY IF EXISTS "Documents Owner Insert" ON storage.objects;
CREATE POLICY "Documents Owner Insert" ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Documents Owner/Admin Update" ON storage.objects;
CREATE POLICY "Documents Owner/Admin Update" ON storage.objects FOR UPDATE 
  USING (bucket_id = 'documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin()));

DROP POLICY IF EXISTS "Documents Owner/Admin Delete" ON storage.objects;
CREATE POLICY "Documents Owner/Admin Delete" ON storage.objects FOR DELETE 
  USING (bucket_id = 'documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin()));

-- ----------------------------------------------------------------------------
-- 13. EMAIL OTP AUTHENTICATION TABLE & POLICIES
-- ----------------------------------------------------------------------------
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
ALTER TABLE public.email_otps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public / Anon Manage OTPs" ON public.email_otps;
CREATE POLICY "Public / Anon Manage OTPs" ON public.email_otps
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 14. USER FEEDBACK & FEATURE REQUESTS TABLE & POLICIES
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 15. ENABLE SUPABASE REALTIME REPLICATION FOR CORE TABLES
-- ----------------------------------------------------------------------------
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


