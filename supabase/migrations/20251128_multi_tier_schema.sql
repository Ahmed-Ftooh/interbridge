BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper predicate for admin checks
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((auth.jwt() ->> 'is_admin')::boolean, false);
$$;

-- Enum definitions (idempotent)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpreter_level_type') THEN
    CREATE TYPE interpreter_level_type AS ENUM ('beginner','junior','professional');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employment_type') THEN
    CREATE TYPE employment_type AS ENUM ('volunteer','paid');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'shift_type') THEN
    CREATE TYPE shift_type AS ENUM ('morning','night','emergency');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'call_type') THEN
    CREATE TYPE call_type AS ENUM ('humanitarian','medical');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_plan_type') THEN
    CREATE TYPE subscription_plan_type AS ENUM ('basic','standard','premium');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status_type') THEN
    CREATE TYPE subscription_status_type AS ENUM ('inactive','trial','active','past_due','canceled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'institution_user_role_type') THEN
    CREATE TYPE institution_user_role_type AS ENUM ('admin','doctor');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'institution_user_status_type') THEN
    CREATE TYPE institution_user_status_type AS ENUM ('pending','active','suspended');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpreter_application_status_type') THEN
    CREATE TYPE interpreter_application_status_type AS ENUM ('draft','submitted','approved','rejected');
  END IF;
END $$;

-- Institutions table
CREATE TABLE IF NOT EXISTS public.institutions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subscription_plan subscription_plan_type NOT NULL DEFAULT 'basic',
  included_minutes integer NOT NULL DEFAULT 0,
  minutes_used_this_cycle integer NOT NULL DEFAULT 0,
  subscription_status subscription_status_type NOT NULL DEFAULT 'inactive',
  subscription_start timestamptz,
  subscription_end timestamptz,
  billing_contact jsonb NOT NULL DEFAULT '{}'::jsonb,
  active_users integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS institutions_set_updated_at ON public.institutions;
CREATE TRIGGER institutions_set_updated_at
BEFORE UPDATE ON public.institutions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- Interpreter applications (idempotent so migration works even if previous file ran)
CREATE TABLE IF NOT EXISTS public.interpreter_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status interpreter_application_status_type NOT NULL DEFAULT 'draft',
  reviewer_id uuid REFERENCES auth.users(id),
  documents jsonb NOT NULL DEFAULT '{}'::jsonb,
  medical_test_snapshot jsonb,
  level_snapshot interpreter_level_type,
  shift_snapshot jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  decided_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS interpreter_applications_user_id_idx ON public.interpreter_applications(user_id);

ALTER TABLE public.interpreter_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own_interpreter_applications" ON public.interpreter_applications;
CREATE POLICY "users_select_own_interpreter_applications"
  ON public.interpreter_applications
  FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "users_insert_interpreter_applications" ON public.interpreter_applications;
CREATE POLICY "users_insert_interpreter_applications"
  ON public.interpreter_applications
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_update_own_interpreter_applications" ON public.interpreter_applications;
CREATE POLICY "users_update_own_interpreter_applications"
  ON public.interpreter_applications
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "admins_manage_interpreter_applications" ON public.interpreter_applications;
CREATE POLICY "admins_manage_interpreter_applications"
  ON public.interpreter_applications
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Users profile enrichment
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS experience_years integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS interpreter_level interpreter_level_type NOT NULL DEFAULT 'beginner',
  ADD COLUMN IF NOT EXISTS employment_type employment_type NOT NULL DEFAULT 'volunteer',
  ADD COLUMN IF NOT EXISTS shift_availability jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS voice_sample_url text,
  ADD COLUMN IF NOT EXISTS general_certificate_url text,
  ADD COLUMN IF NOT EXISTS medical_certificate_url text,
  ADD COLUMN IF NOT EXISTS medical_test_score integer,
  ADD COLUMN IF NOT EXISTS medical_test_duration_seconds integer,
  ADD COLUMN IF NOT EXISTS medical_test_passed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS volunteer_minutes_accumulated integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS institution_id uuid REFERENCES public.institutions(id),
  ADD COLUMN IF NOT EXISTS last_application_id uuid REFERENCES public.interpreter_applications(id);

CREATE INDEX IF NOT EXISTS users_profile_institution_id_idx ON public.users_profile (institution_id);

UPDATE public.users_profile
SET interpreter_level =
  CASE
    WHEN experience_years >= 3 THEN 'professional'::interpreter_level_type
    WHEN experience_years >= 1 THEN 'junior'::interpreter_level_type
    ELSE 'beginner'::interpreter_level_type
  END
WHERE interpreter_level IS NULL OR interpreter_level = 'beginner';

-- Shift slots
CREATE TABLE IF NOT EXISTS public.interpreter_shift_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shift_type shift_type NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  is_on_call boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS interpreter_shift_slots_user_idx ON public.interpreter_shift_slots(user_id);
CREATE INDEX IF NOT EXISTS interpreter_shift_slots_window_idx ON public.interpreter_shift_slots(user_id, start_time, end_time);

-- Call logs
CREATE TABLE IF NOT EXISTS public.call_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text,
  interpreter_id uuid NOT NULL REFERENCES auth.users(id),
  requester_id uuid REFERENCES auth.users(id),
  institution_id uuid REFERENCES public.institutions(id),
  call_type call_type NOT NULL,
  shift_type shift_type,
  is_emergency boolean NOT NULL DEFAULT false,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds integer NOT NULL DEFAULT 0,
  volunteer_minutes_awarded integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS call_logs_interpreter_idx ON public.call_logs(interpreter_id);
CREATE INDEX IF NOT EXISTS call_logs_institution_idx ON public.call_logs(institution_id);
CREATE INDEX IF NOT EXISTS call_logs_started_idx ON public.call_logs(started_at);

-- Volunteer certificates
CREATE TABLE IF NOT EXISTS public.volunteer_certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interpreter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  minutes_awarded integer NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  certificate_url text
);
CREATE INDEX IF NOT EXISTS volunteer_certificates_interpreter_idx ON public.volunteer_certificates(interpreter_id);

-- Institution users
CREATE TABLE IF NOT EXISTS public.institution_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id uuid NOT NULL REFERENCES public.institutions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role institution_user_role_type NOT NULL DEFAULT 'doctor',
  status institution_user_status_type NOT NULL DEFAULT 'pending',
  invited_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS institution_users_unique_idx ON public.institution_users (institution_id, user_id);

-- Medical quiz tables
CREATE TABLE IF NOT EXISTS public.medical_test_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prompt text NOT NULL,
  options jsonb NOT NULL,
  correct_option text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  time_limit_seconds integer NOT NULL DEFAULT 60,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.medical_test_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score integer NOT NULL,
  duration_seconds integer NOT NULL,
  passed boolean NOT NULL,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  question_ids uuid[]
);
CREATE INDEX IF NOT EXISTS medical_test_attempts_user_idx ON public.medical_test_attempts(user_id);

-- Active shift materialized view & trigger
DROP MATERIALIZED VIEW IF EXISTS public.active_shift_interpreters;
CREATE MATERIALIZED VIEW public.active_shift_interpreters AS
SELECT
  iss.user_id,
  u.interpreter_level,
  iss.shift_type,
  iss.is_on_call,
  iss.start_time,
  iss.end_time
FROM public.interpreter_shift_slots iss
JOIN public.users_profile u ON u.user_id = iss.user_id
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS active_shift_interpreters_pk
  ON public.active_shift_interpreters(user_id, shift_type, start_time);

CREATE OR REPLACE FUNCTION public.refresh_active_shift_interpreters()
RETURNS trigger AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.active_shift_interpreters;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS refresh_active_shift_interpreters ON public.interpreter_shift_slots;
CREATE TRIGGER refresh_active_shift_interpreters
AFTER INSERT OR UPDATE OR DELETE ON public.interpreter_shift_slots
FOR EACH STATEMENT
EXECUTE FUNCTION public.refresh_active_shift_interpreters();

-- Subscription helper
CREATE OR REPLACE FUNCTION public.activate_institution_subscription(
  p_institution_id uuid,
  p_duration_days integer DEFAULT 30
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.institutions
  SET
    subscription_status = 'active',
    subscription_start = now(),
    subscription_end = now() + (p_duration_days || ' days')::interval,
    minutes_used_this_cycle = 0
  WHERE id = p_institution_id;
END;
$$;

-- Call log trigger for volunteer minutes & usage
CREATE OR REPLACE FUNCTION public.call_logs_after_insert()
RETURNS trigger AS $$
DECLARE
  minutes integer;
  total_minutes integer;
BEGIN
  minutes := CEIL(COALESCE(NEW.duration_seconds, 0)::numeric / 60);
  IF NEW.call_type = 'humanitarian' THEN
    UPDATE public.users_profile
    SET volunteer_minutes_accumulated = volunteer_minutes_accumulated + minutes
    WHERE user_id = NEW.interpreter_id
    RETURNING volunteer_minutes_accumulated INTO total_minutes;

    IF total_minutes >= 1000 THEN
      INSERT INTO public.volunteer_certificates(interpreter_id, minutes_awarded)
      VALUES (NEW.interpreter_id, total_minutes);

      UPDATE public.users_profile
      SET volunteer_minutes_accumulated = total_minutes - 1000
      WHERE user_id = NEW.interpreter_id;
    END IF;
  END IF;

  IF NEW.institution_id IS NOT NULL THEN
    UPDATE public.institutions
    SET minutes_used_this_cycle = minutes_used_this_cycle + minutes
    WHERE id = NEW.institution_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS call_logs_after_insert ON public.call_logs;
CREATE TRIGGER call_logs_after_insert
AFTER INSERT ON public.call_logs
FOR EACH ROW
EXECUTE FUNCTION public.call_logs_after_insert();

-- RLS for core tables
ALTER TABLE public.interpreter_shift_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteer_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.institution_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_test_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.institutions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "interpreters_manage_own_shifts" ON public.interpreter_shift_slots;
CREATE POLICY "interpreters_manage_own_shifts"
  ON public.interpreter_shift_slots
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "admins_view_all_shifts" ON public.interpreter_shift_slots;
CREATE POLICY "admins_view_all_shifts"
  ON public.interpreter_shift_slots
  FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "interpreters_read_own_calls" ON public.call_logs;
CREATE POLICY "interpreters_read_own_calls"
  ON public.call_logs
  FOR SELECT
  USING (auth.uid() IN (interpreter_id, requester_id) OR public.is_admin());

DROP POLICY IF EXISTS "interpreters_read_own_certificates" ON public.volunteer_certificates;
CREATE POLICY "interpreters_read_own_certificates"
  ON public.volunteer_certificates
  FOR SELECT
  USING (auth.uid() = interpreter_id OR public.is_admin());

DROP POLICY IF EXISTS "institution_users_read_self" ON public.institution_users;
CREATE POLICY "institution_users_read_self"
  ON public.institution_users
  FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "admins_manage_institution_users" ON public.institution_users;
CREATE POLICY "admins_manage_institution_users"
  ON public.institution_users
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "medical_attempts_self" ON public.medical_test_attempts;
CREATE POLICY "medical_attempts_self"
  ON public.medical_test_attempts
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "medical_attempts_admin" ON public.medical_test_attempts;
CREATE POLICY "medical_attempts_admin"
  ON public.medical_test_attempts
  FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "medical_questions_public" ON public.medical_test_questions;
CREATE POLICY "medical_questions_public"
  ON public.medical_test_questions
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "medical_questions_admin" ON public.medical_test_questions;
CREATE POLICY "medical_questions_admin"
  ON public.medical_test_questions
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "institutions_admin" ON public.institutions;
CREATE POLICY "institutions_admin"
  ON public.institutions
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Storage buckets & policies
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'voice_samples') THEN
    INSERT INTO storage.buckets (id, name, public) VALUES ('voice_samples','voice_samples',false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'interpreter_certificates') THEN
    INSERT INTO storage.buckets (id, name, public) VALUES ('interpreter_certificates','interpreter_certificates',false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'medical_tests') THEN
    INSERT INTO storage.buckets (id, name, public) VALUES ('medical_tests','medical_tests',false);
  END IF;
END $$;

-- Storage policies (operate on storage.objects)
DROP POLICY IF EXISTS "voice_samples_owner" ON storage.objects;
CREATE POLICY "voice_samples_owner"
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'voice_samples' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'voice_samples' AND auth.uid() = owner);

DROP POLICY IF EXISTS "voice_samples_admin_read" ON storage.objects;
CREATE POLICY "voice_samples_admin_read"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'voice_samples' AND public.is_admin());

DROP POLICY IF EXISTS "certificates_owner" ON storage.objects;
CREATE POLICY "certificates_owner"
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'interpreter_certificates' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'interpreter_certificates' AND auth.uid() = owner);

DROP POLICY IF EXISTS "certificates_admin_read" ON storage.objects;
CREATE POLICY "certificates_admin_read"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'interpreter_certificates' AND public.is_admin());

DROP POLICY IF EXISTS "medical_tests_admin" ON storage.objects;
CREATE POLICY "medical_tests_admin"
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'medical_tests' AND public.is_admin())
  WITH CHECK (bucket_id = 'medical_tests' AND public.is_admin());

COMMIT;