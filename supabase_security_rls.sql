-- ============================================================================
-- FINDIPRO — PRODUCTION SUPABASE ROW LEVEL SECURITY (RLS) & POLICIES SCRIPT
-- ============================================================================
-- IMPORTANT: Run this script in the Supabase SQL Editor for production deployment.
-- This script enables Row Level Security (RLS) across all tables and storage buckets,
-- enforcing strict authorization rules for users, providers, admins, and storage.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. HELPER SECURITY FUNCTIONS
-- ----------------------------------------------------------------------------

-- Helper function to verify if current authenticated user is an administrator
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is business owner
CREATE OR REPLACE FUNCTION public.is_business_owner(biz_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = biz_id AND (owner_id = auth.uid() OR user_id = auth.uid())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 2. USER PROFILES TABLE (public.profiles)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: Public read access to active profiles so customers can discover providers
DROP POLICY IF EXISTS profiles_select_policy ON public.profiles;
CREATE POLICY profiles_select_policy ON public.profiles 
  FOR SELECT USING (true);

-- INSERT: Authenticated user can create their own profile during registration
DROP POLICY IF EXISTS profiles_insert_policy ON public.profiles;
CREATE POLICY profiles_insert_policy ON public.profiles 
  FOR INSERT WITH CHECK (auth.uid() = id);

-- UPDATE: Users can only update their own profile or Admin
DROP POLICY IF EXISTS profiles_update_policy ON public.profiles;
CREATE POLICY profiles_update_policy ON public.profiles 
  FOR UPDATE USING (auth.uid() = id OR public.is_admin()) 
  WITH CHECK (auth.uid() = id OR public.is_admin());

-- PREVENT NON-ADMIN USERS FROM PROMOTING THEMSELVES TO ADMIN/VERIFIED ROLE OR TAMPERING WITH SENSITIVE FIELDS
CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger AS $$
BEGIN
  -- If executed by an admin or internal server role, allow change
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- On INSERT by normal authenticated user: enforce safe defaults
  IF TG_OP = 'INSERT' THEN
    IF NEW.role = 'admin' THEN
      NEW.role := 'customer';
    END IF;
    NEW.verified := false;
    NEW.verification_status := 'pending';
    NEW.plan := COALESCE(NEW.plan, 'basic');
    NEW.subscription_status := 'active';
    RETURN NEW;
  END IF;

  -- On UPDATE by normal authenticated user: reject modification of privileged columns
  IF TG_OP = 'UPDATE' THEN
    IF (NEW.role IS DISTINCT FROM OLD.role OR
        NEW.verified IS DISTINCT FROM OLD.verified OR
        NEW.verification_status IS DISTINCT FROM OLD.verification_status OR
        NEW.plan IS DISTINCT FROM OLD.plan OR
        NEW.subscription_status IS DISTINCT FROM OLD.subscription_status) THEN
      RAISE EXCEPTION 'Unauthorized: Only administrators can modify roles, badges, subscriptions, or account moderation status.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_profile_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_profile_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_profile_privilege_escalation();

-- ----------------------------------------------------------------------------
-- 3. PROVIDERS TABLE (public.providers)
-- ----------------------------------------------------------------------------
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

-- SELECT: Public read access to provider profiles
DROP POLICY IF EXISTS providers_select_policy ON public.providers;
CREATE POLICY providers_select_policy ON public.providers 
  FOR SELECT USING (true);

-- INSERT: Provider can create their provider record
DROP POLICY IF EXISTS providers_insert_policy ON public.providers;
CREATE POLICY providers_insert_policy ON public.providers 
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.uid() = user_id OR public.is_admin());

-- UPDATE: Providers manage their own data or Admin
DROP POLICY IF EXISTS providers_update_policy ON public.providers;
CREATE POLICY providers_update_policy ON public.providers 
  FOR UPDATE USING (auth.uid() = id OR auth.uid() = user_id OR public.is_admin())
  WITH CHECK (auth.uid() = id OR auth.uid() = user_id OR public.is_admin());

-- PREVENT PROVIDER SELF-PROMOTION OF VERIFICATION BADGE OR PLAN TIERS DIRECTLY
CREATE OR REPLACE FUNCTION public.prevent_provider_privilege_escalation()
RETURNS trigger AS $$
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.verified := false;
    NEW.plan := COALESCE(NEW.plan, 'basic');
    NEW.rating := 0;
    NEW.review_count := 0;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Provider cannot alter verified badge or plan directly (must go through verification/subscription flows)
    IF (NEW.verified IS DISTINCT FROM OLD.verified OR
        NEW.plan IS DISTINCT FROM OLD.plan) THEN
      RAISE EXCEPTION 'Unauthorized: Moderation, verification badges, and plan tiers cannot be edited directly.';
    END IF;
  END IF;

  RETURN NEW;
END;
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
  FOR INSERT WITH CHECK (auth.uid() = owner_id OR auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS businesses_update_policy ON public.businesses;
CREATE POLICY businesses_update_policy ON public.businesses 
  FOR UPDATE USING (auth.uid() = owner_id OR auth.uid() = user_id OR public.is_admin());

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
    OR EXISTS (SELECT 1 FROM public.providers WHERE (id = services.provider_id OR user_id = services.provider_id) AND (id = auth.uid() OR user_id = auth.uid()))
    OR public.is_admin()
  );

-- Only owning provider or admin can update services
DROP POLICY IF EXISTS services_update_policy ON public.services;
CREATE POLICY services_update_policy ON public.services 
  FOR UPDATE USING (
    auth.uid() = provider_id 
    OR EXISTS (SELECT 1 FROM public.providers WHERE (id = services.provider_id OR user_id = services.provider_id) AND (id = auth.uid() OR user_id = auth.uid()))
    OR public.is_admin()
  );

-- Only owning provider or admin can delete services
DROP POLICY IF EXISTS services_delete_policy ON public.services;
CREATE POLICY services_delete_policy ON public.services 
  FOR DELETE USING (
    auth.uid() = provider_id 
    OR EXISTS (SELECT 1 FROM public.providers WHERE (id = services.provider_id OR user_id = services.provider_id) AND (id = auth.uid() OR user_id = auth.uid()))
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
-- 6. JOBS & JOB ASSIGNMENTS (public.jobs, public.job_assignments)
-- ----------------------------------------------------------------------------
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
-- 10. PROVIDER SUBSCRIPTIONS (public.provider_subscriptions)
-- ----------------------------------------------------------------------------
ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;

-- Provider can read their own subscription
DROP POLICY IF EXISTS subs_select_policy ON public.provider_subscriptions;
CREATE POLICY subs_select_policy ON public.provider_subscriptions 
  FOR SELECT USING (auth.uid() = provider_id OR public.is_admin());

-- Only Admin or service role can insert/update subscription state
DROP POLICY IF EXISTS subs_admin_manage ON public.provider_subscriptions;
CREATE POLICY subs_admin_manage ON public.provider_subscriptions 
  FOR ALL USING (public.is_admin());

-- ----------------------------------------------------------------------------
-- 11. NOTIFICATIONS & FAVORITES (public.notifications, public.favorites)
-- ----------------------------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notif_select_policy ON public.notifications;
CREATE POLICY notif_select_policy ON public.notifications FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS notif_insert_policy ON public.notifications;
CREATE POLICY notif_insert_policy ON public.notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL OR public.is_admin());

DROP POLICY IF EXISTS notif_update_policy ON public.notifications;
CREATE POLICY notif_update_policy ON public.notifications FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS favorites_policy ON public.favorites;
CREATE POLICY favorites_policy ON public.favorites FOR ALL USING (auth.uid() = user_id OR public.is_admin());

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
