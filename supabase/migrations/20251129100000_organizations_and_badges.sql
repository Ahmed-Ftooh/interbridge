-- Migration: Organizations, Badges, Quiz Sections, Admin Chat
-- Date: 2025-11-29
-- Description: Adds organization wallet system, interpreter badges, quiz sections, admin-interpreter messaging

BEGIN;

-- ============================================
-- ORGANIZATIONS (Pay-as-you-go wallet system)
-- ============================================
CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE,
  phone text,
  address text,
  wallet_balance decimal(10,2) NOT NULL DEFAULT 0.00,
  rate_per_minute decimal(10,2) NOT NULL DEFAULT 1.00,
  invite_code text UNIQUE DEFAULT upper(substring(md5(random()::text) from 1 for 8)),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS organizations_set_updated_at ON public.organizations;
CREATE TRIGGER organizations_set_updated_at
BEFORE UPDATE ON public.organizations
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ============================================
-- ORGANIZATION USERS (Admins & Doctors)
-- ============================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_user_role') THEN
    CREATE TYPE org_user_role AS ENUM ('organization_admin', 'doctor');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.organization_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role org_user_role NOT NULL DEFAULT 'doctor',
  is_active boolean NOT NULL DEFAULT true,
  spending_limit decimal(10,2), -- Optional per-doctor limit
  total_spent decimal(10,2) NOT NULL DEFAULT 0.00,
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(organization_id, user_id)
);

CREATE INDEX IF NOT EXISTS organization_members_org_idx ON public.organization_members(organization_id);
CREATE INDEX IF NOT EXISTS organization_members_user_idx ON public.organization_members(user_id);

-- ============================================
-- INTERPRETER BADGES (Medical specializations)
-- ============================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'badge_type') THEN
    CREATE TYPE badge_type AS ENUM (
      'general_medical',
      'neurology',
      'cardiology',
      'emergency',
      'oncology',
      'psychiatry',
      'internal_medicine'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.interpreter_badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge badge_type NOT NULL,
  score integer NOT NULL, -- Score achieved (0-100)
  earned_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, badge)
);

CREATE INDEX IF NOT EXISTS interpreter_badges_user_idx ON public.interpreter_badges(user_id);

-- ============================================
-- QUIZ SECTIONS & RESULTS
-- ============================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quiz_section') THEN
    CREATE TYPE quiz_section AS ENUM (
      'general',
      'neurology',
      'cardiology',
      'emergency',
      'oncology',
      'psychiatry',
      'internal_medicine'
    );
  END IF;
END $$;

-- Note: medical_test_questions alterations skipped - table may not exist yet
-- The section column will be added when the multi-tier schema is applied

-- Quiz section results (per section scores)
CREATE TABLE IF NOT EXISTS public.quiz_section_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attempt_id uuid, -- Reference to medical_test_attempts if exists
  section quiz_section NOT NULL,
  correct_count integer NOT NULL DEFAULT 0,
  total_questions integer NOT NULL DEFAULT 0,
  score integer NOT NULL DEFAULT 0, -- Percentage 0-100
  passed boolean NOT NULL DEFAULT false, -- 80% threshold
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, section)
);

CREATE INDEX IF NOT EXISTS quiz_section_results_user_idx ON public.quiz_section_results(user_id);

-- ============================================
-- ADMIN-INTERPRETER MESSAGING
-- ============================================
CREATE TABLE IF NOT EXISTS public.admin_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  interpreter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text NOT NULL,
  is_from_admin boolean NOT NULL DEFAULT true,
  is_read boolean NOT NULL DEFAULT false,
  sent_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_messages_interpreter_idx ON public.admin_messages(interpreter_id);
CREATE INDEX IF NOT EXISTS admin_messages_admin_idx ON public.admin_messages(admin_id);
CREATE INDEX IF NOT EXISTS admin_messages_sent_idx ON public.admin_messages(sent_at);

-- ============================================
-- INTERPRETER DETAILS UPDATES
-- ============================================
ALTER TABLE public.interpreter_details
  ADD COLUMN IF NOT EXISTS is_online boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS current_call_id uuid,
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz DEFAULT now();

CREATE INDEX IF NOT EXISTS interpreter_details_online_idx ON public.interpreter_details(is_online) WHERE is_online = true;

-- ============================================
-- CALL LOGS UPDATES (for tracking)
-- ============================================
ALTER TABLE public.call_logs
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id),
  ADD COLUMN IF NOT EXISTS cost decimal(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS admin_listener_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS recording_url text;

-- ============================================
-- FLEXIBLE SHIFTS
-- ============================================
CREATE TABLE IF NOT EXISTS public.interpreter_flexible_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_of_week integer NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday, 6=Saturday
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, day_of_week, start_time, end_time)
);

CREATE INDEX IF NOT EXISTS interpreter_flexible_shifts_user_idx ON public.interpreter_flexible_shifts(user_id);

-- ============================================
-- RLS POLICIES
-- ============================================
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interpreter_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_section_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interpreter_flexible_shifts ENABLE ROW LEVEL SECURITY;

-- Organizations: admins can manage, members can view their org
DROP POLICY IF EXISTS "org_admins_manage" ON public.organizations;
CREATE POLICY "org_admins_manage"
  ON public.organizations
  FOR ALL
  USING (public.is_admin() OR id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = auth.uid() AND role = 'organization_admin'
  ))
  WITH CHECK (public.is_admin() OR id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = auth.uid() AND role = 'organization_admin'
  ));

DROP POLICY IF EXISTS "org_members_view" ON public.organizations;
CREATE POLICY "org_members_view"
  ON public.organizations
  FOR SELECT
  USING (id IN (
    SELECT organization_id FROM public.organization_members WHERE user_id = auth.uid()
  ));

-- Organization members
DROP POLICY IF EXISTS "org_members_self_view" ON public.organization_members;
CREATE POLICY "org_members_self_view"
  ON public.organization_members
  FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin() OR organization_id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = auth.uid() AND role = 'organization_admin'
  ));

DROP POLICY IF EXISTS "org_admins_manage_members" ON public.organization_members;
CREATE POLICY "org_admins_manage_members"
  ON public.organization_members
  FOR ALL
  USING (public.is_admin() OR organization_id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = auth.uid() AND role = 'organization_admin'
  ))
  WITH CHECK (public.is_admin() OR organization_id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = auth.uid() AND role = 'organization_admin'
  ));

-- Badges: users see own, admins see all
DROP POLICY IF EXISTS "badges_self_view" ON public.interpreter_badges;
CREATE POLICY "badges_self_view"
  ON public.interpreter_badges
  FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "badges_system_manage" ON public.interpreter_badges;
CREATE POLICY "badges_system_manage"
  ON public.interpreter_badges
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Quiz section results
DROP POLICY IF EXISTS "quiz_results_self" ON public.quiz_section_results;
CREATE POLICY "quiz_results_self"
  ON public.quiz_section_results
  FOR ALL
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid());

-- Admin messages
DROP POLICY IF EXISTS "admin_messages_participants" ON public.admin_messages;
CREATE POLICY "admin_messages_participants"
  ON public.admin_messages
  FOR ALL
  USING (admin_id = auth.uid() OR interpreter_id = auth.uid() OR public.is_admin())
  WITH CHECK (admin_id = auth.uid() OR interpreter_id = auth.uid() OR public.is_admin());

-- Flexible shifts
DROP POLICY IF EXISTS "shifts_self_manage" ON public.interpreter_flexible_shifts;
CREATE POLICY "shifts_self_manage"
  ON public.interpreter_flexible_shifts
  FOR ALL
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to check if interpreter is currently on shift
CREATE OR REPLACE FUNCTION public.is_interpreter_on_shift(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  current_dow integer;
  current_time_val time;
BEGIN
  current_dow := EXTRACT(DOW FROM now());
  current_time_val := LOCALTIME;
  
  RETURN EXISTS (
    SELECT 1 FROM public.interpreter_flexible_shifts
    WHERE user_id = p_user_id
      AND day_of_week = current_dow
      AND start_time <= current_time_val
      AND end_time > current_time_val
      AND is_active = true
  );
END;
$$;

-- Function to deduct from organization wallet after call
CREATE OR REPLACE FUNCTION public.deduct_call_cost()
RETURNS trigger AS $$
DECLARE
  call_cost decimal(10,2);
  org_rate decimal(10,2);
  caller_id uuid;
BEGIN
  -- Only process if call has ended and has organization
  IF NEW.ended_at IS NOT NULL AND NEW.organization_id IS NOT NULL THEN
    -- Get organization rate
    SELECT rate_per_minute INTO org_rate
    FROM public.organizations
    WHERE id = NEW.organization_id;
    
    -- Calculate cost (duration in seconds / 60 * rate)
    call_cost := CEIL(COALESCE(NEW.duration_seconds, 0)::numeric / 60) * COALESCE(org_rate, 1.00);
    
    -- Update call log with cost
    NEW.cost := call_cost;
    
    -- Deduct from organization wallet
    UPDATE public.organizations
    SET wallet_balance = wallet_balance - call_cost
    WHERE id = NEW.organization_id;
    
    -- Track doctor spending if requester is a doctor
    UPDATE public.organization_members
    SET total_spent = total_spent + call_cost
    WHERE user_id = NEW.requester_id AND organization_id = NEW.organization_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS call_logs_deduct_cost ON public.call_logs;
CREATE TRIGGER call_logs_deduct_cost
BEFORE UPDATE ON public.call_logs
FOR EACH ROW
WHEN (OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL)
EXECUTE FUNCTION public.deduct_call_cost();

-- Function to award badge when quiz section passed
CREATE OR REPLACE FUNCTION public.award_badge_on_quiz_pass()
RETURNS trigger AS $$
BEGIN
  IF NEW.passed = true AND NEW.score >= 80 THEN
    INSERT INTO public.interpreter_badges (user_id, badge, score)
    VALUES (NEW.user_id, NEW.section::text::badge_type, NEW.score)
    ON CONFLICT (user_id, badge) 
    DO UPDATE SET score = GREATEST(interpreter_badges.score, EXCLUDED.score);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS quiz_award_badge ON public.quiz_section_results;
CREATE TRIGGER quiz_award_badge
AFTER INSERT OR UPDATE ON public.quiz_section_results
FOR EACH ROW
EXECUTE FUNCTION public.award_badge_on_quiz_pass();

-- Note: Quiz questions seeding moved to separate migration
-- to avoid dependency issues with medical_test_questions table

COMMIT;
