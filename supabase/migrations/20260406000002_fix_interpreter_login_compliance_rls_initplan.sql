-- Fix RLS init-plan warnings for interpreter login compliance policies.
-- Wrap auth-dependent calls with SELECT to avoid per-row re-evaluation.

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
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT public.is_admin())
  );

CREATE POLICY interpreter_login_compliance_insert
  ON public.interpreter_login_compliance_photos
  FOR INSERT
  WITH CHECK (
    user_id = (SELECT auth.uid())
  );

CREATE POLICY interpreter_login_compliance_update
  ON public.interpreter_login_compliance_photos
  FOR UPDATE
  USING ((SELECT public.is_admin()))
  WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY interpreter_login_compliance_delete
  ON public.interpreter_login_compliance_photos
  FOR DELETE
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT public.is_admin())
  );
