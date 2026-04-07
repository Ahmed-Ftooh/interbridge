-- Interpreter login compliance selfies.
-- A new selfie is required on each interpreter login and retained for 7 days.

CREATE TABLE IF NOT EXISTS public.interpreter_login_compliance_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  CONSTRAINT interpreter_login_compliance_status_check
    CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_interpreter_login_compliance_user_id
  ON public.interpreter_login_compliance_photos(user_id);

CREATE INDEX IF NOT EXISTS idx_interpreter_login_compliance_expires_at
  ON public.interpreter_login_compliance_photos(expires_at);

ALTER TABLE public.interpreter_login_compliance_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS interpreter_login_compliance_select
  ON public.interpreter_login_compliance_photos;
DROP POLICY IF EXISTS interpreter_login_compliance_insert
  ON public.interpreter_login_compliance_photos;
DROP POLICY IF EXISTS interpreter_login_compliance_update
  ON public.interpreter_login_compliance_photos;
DROP POLICY IF EXISTS interpreter_login_compliance_delete
  ON public.interpreter_login_compliance_photos;

CREATE POLICY interpreter_login_compliance_select
  ON public.interpreter_login_compliance_photos
  FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY interpreter_login_compliance_insert
  ON public.interpreter_login_compliance_photos
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY interpreter_login_compliance_update
  ON public.interpreter_login_compliance_photos
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY interpreter_login_compliance_delete
  ON public.interpreter_login_compliance_photos
  FOR DELETE
  USING (user_id = auth.uid() OR public.is_admin());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'interpreter-login-compliance'
  ) THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('interpreter-login-compliance', 'interpreter-login-compliance', false);
  END IF;
END $$;

DROP POLICY IF EXISTS "interpreter_login_compliance_owner"
  ON storage.objects;
DROP POLICY IF EXISTS "interpreter_login_compliance_admin_read"
  ON storage.objects;

CREATE POLICY "interpreter_login_compliance_owner"
  ON storage.objects
  FOR ALL
  USING (
    bucket_id = 'interpreter-login-compliance'
    AND auth.uid() = owner
  )
  WITH CHECK (
    bucket_id = 'interpreter-login-compliance'
    AND auth.uid() = owner
  );

CREATE POLICY "interpreter_login_compliance_admin_read"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'interpreter-login-compliance'
    AND public.is_admin()
  );
