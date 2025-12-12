BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpreter_application_status_type') THEN
    CREATE TYPE interpreter_application_status_type AS ENUM ('draft','submitted','approved','rejected');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpreter_level_type') THEN
    CREATE TYPE interpreter_level_type AS ENUM ('beginner','junior','professional');
  END IF;
END
$$;

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

CREATE UNIQUE INDEX IF NOT EXISTS interpreter_applications_user_id_idx
  ON public.interpreter_applications(user_id);

ALTER TABLE public.interpreter_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own_interpreter_applications" ON public.interpreter_applications;
CREATE POLICY "users_select_own_interpreter_applications"
  ON public.interpreter_applications
  FOR SELECT
  USING (auth.uid() = user_id);

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

COMMIT;
