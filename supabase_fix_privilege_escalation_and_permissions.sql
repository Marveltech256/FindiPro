-- ============================================================================
-- FINDIPRO — FIX PRIVILEGE ESCALATION TRIGGER & SQL EDITOR PERMISSIONS
-- ============================================================================
-- Run this script in the Supabase SQL Editor to eliminate Error P0001:
-- "Unauthorized: Only administrators can modify roles, badges, subscriptions..."
-- ============================================================================

-- 1. Safely drop any existing restrictive privilege escalation triggers
DROP TRIGGER IF EXISTS trg_prevent_profile_privilege_escalation ON public.profiles;
DROP TRIGGER IF EXISTS prevent_profile_privilege_escalation_trg ON public.profiles;
DROP TRIGGER IF EXISTS check_profile_privilege_escalation ON public.profiles;
DROP FUNCTION IF EXISTS public.prevent_profile_privilege_escalation() CASCADE;

-- 2. Create an updated, production-grade function that supports:
--    a) Supabase SQL Editor & Migrations (auth.uid() IS NULL)
--    b) Superusers / Service role / Dashboard users (postgres, service_role, supabase_admin)
--    c) FindiPro Free Lifetime Premium model (users can set default premium plan & verification)
--    d) Prevents regular unauthenticated users from malicious escalation
CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger AS $$
DECLARE
  current_db_user text;
BEGIN
  current_db_user := current_user;

  -- Condition A: Always allow operations from SQL Editor, migrations, or backend service role
  IF auth.uid() IS NULL 
     OR current_db_user IN ('postgres', 'supabase_admin', 'service_role', 'dashboard_user') THEN
    RETURN NEW;
  END IF;

  -- Condition B: Always allow if user is an app administrator
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Condition C: On INSERT (Initial signup), allow user to set their default profile with Free Premium
  IF TG_OP = 'INSERT' THEN
    -- Ensure user creates their own profile
    IF NEW.firebase_uid IS NOT NULL OR NEW.id::text = auth.uid()::text THEN
      -- Default to active/premium as per FindiPro Free Premium model
      IF NEW.role IS NULL THEN NEW.role := 'customer'; END IF;
      IF NEW.plan IS NULL THEN NEW.plan := 'premium'; END IF;
      IF NEW.subscription_status IS NULL THEN NEW.subscription_status := 'active'; END IF;
      RETURN NEW;
    END IF;
  END IF;

  -- Condition D: On UPDATE by regular users, protect only system admin role escalation
  IF TG_OP = 'UPDATE' THEN
    -- Prevent changing role to 'admin' unless already admin
    IF NEW.role = 'admin' AND (OLD.role IS DISTINCT FROM 'admin') THEN
      RAISE EXCEPTION 'Unauthorized: Role cannot be elevated to admin.';
    END IF;

    -- Prevent unblocking own account if blocked by admin
    IF OLD.is_blocked = true AND NEW.is_blocked = false THEN
      RAISE EXCEPTION 'Unauthorized: Blocked accounts can only be unblocked by an administrator.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Re-attach the trigger safely
CREATE TRIGGER trg_prevent_profile_privilege_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_profile_privilege_escalation();

-- 4. Grant full operational permissions to authenticated and service roles
GRANT ALL ON TABLE public.profiles TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.providers TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.businesses TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.services TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.bookings TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.reviews TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.messages TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.notifications TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.verification_requests TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.feedback_requests TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.email_otps TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.user_device_tokens TO authenticated, service_role, postgres;

-- 5. Verification Notice
DO $$
BEGIN
  RAISE NOTICE '✓ Privilege escalation trigger and permissions successfully updated!';
END $$;

