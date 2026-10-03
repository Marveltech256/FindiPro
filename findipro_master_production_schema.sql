-- ============================================================================
-- FINDIPRO — COMPLETE MASTER PRODUCTION DATABASE SCHEMA & CONFIGURATION
-- ============================================================================
-- Safe & 100% Idempotent: Run this in the Supabase SQL Editor.
-- Handles existing tables gracefully by adding any missing columns before indexing.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 2. CREATE TABLES (IF NOT EXIST) & ENSURE ALL COLUMNS EXIST
-- ----------------------------------------------------------------------------

-- 2.1 PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE,
    uid TEXT,
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
    is_verified BOOLEAN DEFAULT true,
    is_premium BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT true,
    is_blocked BOOLEAN DEFAULT false,
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT now(),
    images TEXT[] DEFAULT '{}',
    portfolio_images TEXT[] DEFAULT '{}',
    verification_status TEXT DEFAULT 'approved',
    subscription_status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS uid TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'customer';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS years_experience INT DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS price_range TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'premium';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS premium BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS portfolio_images TEXT[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'approved';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'active';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2.2 PROVIDERS TABLE
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    firebase_uid TEXT,
    uid TEXT,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    category TEXT,
    subcategory TEXT,
    location TEXT,
    about TEXT,
    bio TEXT,
    skills TEXT[] DEFAULT '{}',
    years_experience INT DEFAULT 0,
    price_range TEXT,
    hourly_rate NUMERIC DEFAULT 0,
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
    is_verified BOOLEAN DEFAULT true,
    is_premium BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT true,
    is_blocked BOOLEAN DEFAULT false,
    verification_status TEXT DEFAULT 'approved',
    subscription_status TEXT DEFAULT 'active',
    images TEXT[] DEFAULT '{}',
    portfolio_images TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS uid TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS subcategory TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS about TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS years_experience INT DEFAULT 0;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS price_range TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC DEFAULT 0;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS available BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS business_name TEXT;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'premium';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS premium BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT true;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'approved';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'active';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS portfolio_images TEXT[] DEFAULT '{}';
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.providers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2.3 BUSINESSES TABLE
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

ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;

-- 2.4 SERVICES TABLE
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    price NUMERIC DEFAULT 0,
    duration_minutes INT DEFAULT 60,
    is_active BOOLEAN DEFAULT true,
    image_url TEXT,
    images TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.services ADD COLUMN IF NOT EXISTS provider_id UUID;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS price NUMERIC DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS duration_minutes INT DEFAULT 60;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}';

-- 2.5 BOOKINGS / ORDERS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID,
    provider_id UUID,
    service_id UUID,
    service_name TEXT,
    status TEXT DEFAULT 'pending',
    scheduled_at TIMESTAMPTZ,
    total_amount NUMERIC DEFAULT 0,
    location TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    payment_status TEXT DEFAULT 'pending',
    payment_method TEXT DEFAULT 'cash',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS customer_id UUID;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS provider_id UUID;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS service_id UUID;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS service_name TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS total_amount NUMERIC DEFAULT 0;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending';
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';

-- 2.6 REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID,
    provider_id UUID,
    customer_id UUID,
    rating NUMERIC NOT NULL DEFAULT 5.0,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS booking_id UUID;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS provider_id UUID;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS customer_id UUID;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 5.0;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS comment TEXT;

-- 2.7 CONVERSATIONS TABLE
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user1_id UUID,
    user2_id UUID,
    last_message TEXT,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS user1_id UUID;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS user2_id UUID;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT now();

-- 2.8 MESSAGES TABLE (Ensuring all messaging columns exist)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID,
    sender_id UUID,
    receiver_id UUID,
    recipient_id UUID,
    sender_uid TEXT,
    recipient_uid TEXT,
    message TEXT,
    text TEXT,
    content TEXT,
    booking_id UUID,
    job_id UUID,
    image_url TEXT,
    attachments TEXT[] DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS conversation_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS receiver_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS recipient_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_uid TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS recipient_uid TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS text TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS booking_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS job_id UUID;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachments TEXT[] DEFAULT '{}';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- 2.9 USER DEVICE TOKENS TABLE (FCM Push Notifications)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    fcm_token TEXT,
    token TEXT,
    platform TEXT,
    device_type TEXT,
    device_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS token TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS platform TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS device_type TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS device_name TEXT;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'unique_user_device_fcm_token'
    ) THEN
        ALTER TABLE public.user_device_tokens 
        ADD CONSTRAINT unique_user_device_fcm_token UNIQUE (user_id, fcm_token);
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_fcm_token ON public.user_device_tokens (fcm_token);

-- 2.10 IN-APP NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'general';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- 2.11 EMAIL OTP AUTHENTICATION TABLE
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

ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS otp_code TEXT;
ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;
ALTER TABLE public.email_otps ADD COLUMN IF NOT EXISTS attempts INT DEFAULT 0;

-- 2.12 USER FEEDBACK & COMMUNITY FEATURE REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.feedback_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    user_name TEXT DEFAULT 'Anonymous',
    user_email TEXT,
    user_role TEXT DEFAULT 'customer',
    type TEXT NOT NULL DEFAULT 'feedback',
    category TEXT NOT NULL DEFAULT 'General',
    title TEXT,
    description TEXT NOT NULL,
    rating NUMERIC DEFAULT 5.0,
    status TEXT DEFAULT 'pending',
    votes INT DEFAULT 0,
    upvoter_uids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS user_name TEXT DEFAULT 'Anonymous';
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS user_email TEXT;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS user_role TEXT DEFAULT 'customer';
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'feedback';
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General';
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 5.0;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS votes INT DEFAULT 0;
ALTER TABLE public.feedback_requests ADD COLUMN IF NOT EXISTS upvoter_uids TEXT[] DEFAULT '{}';

-- 2.13 SAVED / FAVORITE PROVIDERS TABLE
CREATE TABLE IF NOT EXISTS public.saved_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    provider_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.saved_providers ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.saved_providers ADD COLUMN IF NOT EXISTS provider_id UUID;

-- 2.14 ANALYTICS EVENTS TABLE (Phase 29 Platform Telemetry)
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_name TEXT NOT NULL,
    user_id UUID,
    firebase_uid TEXT,
    platform TEXT,
    parameters JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS event_name TEXT;
ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS platform TEXT;
ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS parameters JSONB DEFAULT '{}';
ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- 2.15 TRUST & SAFETY REPORTS TABLE (Phase 34)
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID,
    reported_user_id UUID,
    reporter_uid TEXT,
    reported_uid TEXT,
    booking_id UUID,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT DEFAULT 'pending',
    action_taken TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reporter_id UUID;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reported_user_id UUID;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reporter_uid TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reported_uid TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS booking_id UUID;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS details TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS action_taken TEXT;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- 2.16 BLOCKED USERS TABLE (Phase 34)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    blocked_user_id UUID NOT NULL,
    user_uid TEXT,
    blocked_uid TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_user_block UNIQUE (user_id, blocked_user_id)
);

ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS blocked_user_id UUID;
ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS user_uid TEXT;
ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS blocked_uid TEXT;
ALTER TABLE public.blocked_users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- 2.17 QUOTATIONS & IN-APP INVOICES TABLE
CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_number TEXT NOT NULL,
    client_id TEXT NOT NULL,
    client_name TEXT NOT NULL,
    client_phone TEXT,
    client_address TEXT,
    provider_id TEXT NOT NULL,
    provider_name TEXT NOT NULL,
    provider_phone TEXT,
    provider_email TEXT,
    provider_address TEXT,
    provider_logo_url TEXT,
    conversation_id TEXT,
    booking_id UUID,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'requested',
    currency TEXT NOT NULL DEFAULT 'UGX',
    items JSONB DEFAULT '[]',
    subtotal NUMERIC NOT NULL DEFAULT 0.0,
    tax NUMERIC NOT NULL DEFAULT 0.0,
    discount NUMERIC NOT NULL DEFAULT 0.0,
    total_amount NUMERIC NOT NULL DEFAULT 0.0,
    notes TEXT,
    attachment_url TEXT,
    is_uploaded_document BOOLEAN DEFAULT false,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS quotation_number TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS client_name TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS client_phone TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS client_address TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_id TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_name TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_phone TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_email TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_address TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS provider_logo_url TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS conversation_id TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS booking_id UUID;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'requested';
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'UGX';
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]';
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0.0;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS tax NUMERIC DEFAULT 0.0;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS discount NUMERIC DEFAULT 0.0;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS total_amount NUMERIC DEFAULT 0.0;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS is_uploaded_document BOOLEAN DEFAULT false;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.quotations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- ----------------------------------------------------------------------------
-- 3. INDEXES (Guaranteed to succeed because all columns exist above)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_quotations_client_id ON public.quotations (client_id);
CREATE INDEX IF NOT EXISTS idx_quotations_provider_id ON public.quotations (provider_id);
CREATE INDEX IF NOT EXISTS idx_quotations_status ON public.quotations (status);
CREATE INDEX IF NOT EXISTS idx_quotations_created_at ON public.quotations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_firebase_uid ON public.profiles (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_profiles_uid ON public.profiles (uid);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles (email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);

CREATE INDEX IF NOT EXISTS idx_providers_user_id ON public.providers (user_id);
CREATE INDEX IF NOT EXISTS idx_providers_firebase_uid ON public.providers (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_providers_uid ON public.providers (uid);
CREATE INDEX IF NOT EXISTS idx_providers_category ON public.providers (category);
CREATE INDEX IF NOT EXISTS idx_providers_rating ON public.providers (rating DESC);

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user_id ON public.user_device_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages (receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_email_otps_email ON public.email_otps (email);
CREATE INDEX IF NOT EXISTS idx_email_otps_created_at ON public.email_otps (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_feedback_requests_type ON public.feedback_requests (type);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_status ON public.feedback_requests (status);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_created_at ON public.feedback_requests (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name ON public.analytics_events (event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON public.analytics_events (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports (status);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON public.reports (reported_user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_pair ON public.blocked_users (user_id, blocked_user_id);

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES — OPEN / PERMISSIVE
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'profiles',
        'providers',
        'businesses',
        'services',
        'bookings',
        'reviews',
        'conversations',
        'messages',
        'user_device_tokens',
        'notifications',
        'email_otps',
        'feedback_requests',
        'saved_providers',
        'analytics_events',
        'reports',
        'blocked_users',
        'quotations'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            EXECUTE format('DROP POLICY IF EXISTS "%s_all_policy" ON public.%I;', tbl, tbl);
            EXECUTE format('CREATE POLICY "%s_all_policy" ON public.%I FOR ALL USING (true) WITH CHECK (true);', tbl, tbl);
        END IF;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 5. STORAGE BUCKETS & STORAGE POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('documents', 'documents', true),
    ('portfolio', 'portfolio', true),
    ('chat_attachments', 'chat_attachments', true),
    ('quotations', 'quotations', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public Storage Read Access" ON storage.objects;
CREATE POLICY "Public Storage Read Access" ON storage.objects
    FOR SELECT
    USING (bucket_id IN ('avatars', 'documents', 'portfolio', 'chat_attachments', 'quotations'));

DROP POLICY IF EXISTS "Allow Uploads to Storage" ON storage.objects;
CREATE POLICY "Allow Uploads to Storage" ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id IN ('avatars', 'documents', 'portfolio', 'chat_attachments', 'quotations'));

DROP POLICY IF EXISTS "Allow Updates to Storage" ON storage.objects;
CREATE POLICY "Allow Updates to Storage" ON storage.objects
    FOR UPDATE
    USING (bucket_id IN ('avatars', 'documents', 'portfolio', 'chat_attachments', 'quotations'))
    WITH CHECK (bucket_id IN ('avatars', 'documents', 'portfolio', 'chat_attachments', 'quotations'));

DROP POLICY IF EXISTS "Allow Deletes from Storage" ON storage.objects;
CREATE POLICY "Allow Deletes from Storage" ON storage.objects
    FOR DELETE
    USING (bucket_id IN ('avatars', 'documents', 'portfolio', 'chat_attachments', 'quotations'));

-- ----------------------------------------------------------------------------
-- 6. REALTIME REPLICATION PUBLICATION
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    tbl_name text;
    realtime_tables text[] := ARRAY[
        'profiles',
        'providers',
        'services',
        'bookings',
        'reviews',
        'conversations',
        'messages',
        'notifications',
        'user_device_tokens',
        'feedback_requests',
        'reports',
        'quotations'
    ];
BEGIN
    FOREACH tbl_name IN ARRAY realtime_tables LOOP
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

-- ----------------------------------------------------------------------------
-- 7. VERIFICATION SUMMARY
-- ----------------------------------------------------------------------------
SELECT 
    table_name,
    (SELECT count(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
ORDER BY table_name;
