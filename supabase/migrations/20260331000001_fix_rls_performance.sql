-- Fix Auth RLS InitPlan Performance Issues for top queried tables
-- Wraps auth.uid() and public.is_admin() with (SELECT ...) to prevent row-by-row full re-evaluation

BEGIN;

-- 1. onesignal_player_ids
DROP POLICY IF EXISTS "Users can manage their own player IDs" ON public.onesignal_player_ids;
CREATE POLICY "Users can manage their own player IDs" ON public.onesignal_player_ids
    FOR ALL USING ((select auth.uid()) = user_id);

-- 2. call_logs (interpreters_read_own_calls)
DROP POLICY IF EXISTS "interpreters_read_own_calls" ON public.call_logs;
CREATE POLICY "interpreters_read_own_calls"
  ON public.call_logs
  FOR SELECT
  USING (
    (select auth.uid()) IN (interpreter_id, requester_id)
    OR (select public.is_admin())
    OR (
      organization_id IS NOT NULL
      AND organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = (select auth.uid())
          AND role = 'organization_admin'
          AND is_active = true
      )
    )
  );

DROP POLICY IF EXISTS "Interpreters can update own call logs" ON public.call_logs;
CREATE POLICY "Interpreters can update own call logs"
  ON public.call_logs
  FOR UPDATE
  USING (interpreter_id = (select auth.uid()))
  WITH CHECK (interpreter_id = (select auth.uid()));

-- 3. organizations self view
DROP POLICY IF EXISTS "org_members_view" ON public.organizations;
CREATE POLICY "org_members_view"
  ON public.organizations
  FOR SELECT
  USING (id IN (
    SELECT organization_id FROM public.organization_members WHERE user_id = (select auth.uid())
  ));

-- 4. organization_members self view
DROP POLICY IF EXISTS "org_members_self_view" ON public.organization_members;
CREATE POLICY "org_members_self_view"
  ON public.organization_members
  FOR SELECT
  USING (user_id = (select auth.uid()) OR (select public.is_admin()) OR organization_id IN (
    SELECT organization_id FROM public.organization_members 
    WHERE user_id = (select auth.uid()) AND role = 'organization_admin'
  ));

-- 5. voice samples (often fetched on login or dashboard load)
DROP POLICY IF EXISTS voice_samples_select ON public.voice_samples;
CREATE POLICY voice_samples_select ON public.voice_samples
  FOR SELECT USING (user_id = (select auth.uid()) OR (select public.is_admin()));

-- 6. interpreter basics
DROP POLICY IF EXISTS "interpreter_details_select" ON public.interpreter_details;
CREATE POLICY interpreter_details_select ON public.interpreter_details
  FOR SELECT 
  USING (
    is_suspended = false 
    OR user_id = (select auth.uid()) 
    OR (select public.is_admin())
  );

COMMIT;