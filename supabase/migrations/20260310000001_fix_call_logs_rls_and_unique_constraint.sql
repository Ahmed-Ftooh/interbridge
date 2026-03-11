-- ============================================================
-- Fix call_logs: unique constraint on request_id + RLS SELECT
-- for organization admins.
--
-- Problem 1: call_logs.request_id had no UNIQUE constraint.
--   Both call participants (interpreter + doctor) call
--   recordCallLog() at hang-up. Without a unique constraint the
--   upsert(onConflict: 'request_id') behaved as a plain INSERT,
--   firing the billing trigger twice and double-charging the
--   organisation wallet.
--
-- Problem 2: The SELECT policy "interpreters_read_own_calls"
--   only allowed interpreter_id / requester_id / superadmin to
--   read call_logs rows. An organisation admin (a different user)
--   could not query call_logs for their organisation, so the
--   Calls tab in the org dashboard always returned an empty list.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. De-duplicate any existing rows before adding UNIQUE.
--    Keep the first-inserted row per request_id (by started_at).
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.call_logs
WHERE id IN (
  SELECT id
  FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY request_id
             ORDER BY started_at ASC, id ASC
           ) AS rn
    FROM public.call_logs
    WHERE request_id IS NOT NULL
  ) ranked
  WHERE rn > 1
);

-- ─────────────────────────────────────────────────────────────
-- 2. Add UNIQUE constraint on request_id.
--    NULL values are excluded (PostgreSQL treats each NULL as
--    distinct, so old rows with NULL request_id are unaffected).
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.call_logs
  ADD CONSTRAINT call_logs_request_id_unique UNIQUE (request_id);

-- ─────────────────────────────────────────────────────────────
-- 3. Replace the SELECT policy on call_logs so that org admins
--    can read all calls that belong to their organisation.
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "interpreters_read_own_calls" ON public.call_logs;

CREATE POLICY "interpreters_read_own_calls"
  ON public.call_logs
  FOR SELECT
  USING (
    -- Interpreter or requester can always see their own calls
    auth.uid() IN (interpreter_id, requester_id)
    -- Superadmin
    OR public.is_admin()
    -- Organisation admin can see all calls for their organisation
    OR (
      organization_id IS NOT NULL
      AND organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND role = 'organization_admin'
          AND is_active = true
      )
    )
  );
