-- Tighten RLS for routing_queue and phone_calls

ALTER TABLE public.routing_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phone_calls ENABLE ROW LEVEL SECURITY;

-- routing_queue policies
DROP POLICY IF EXISTS "routing_queue_access" ON public.routing_queue;
DROP POLICY IF EXISTS "routing_queue_select_participants" ON public.routing_queue;
DROP POLICY IF EXISTS "routing_queue_insert_requester" ON public.routing_queue;
DROP POLICY IF EXISTS "routing_queue_update_participants" ON public.routing_queue;

CREATE POLICY "routing_queue_select_participants" ON public.routing_queue
  FOR SELECT
  USING (
    request_id IN (
      SELECT id FROM public.interpreter_requests
      WHERE requester_id = auth.uid()
         OR accepted_by = auth.uid()
         OR matched_interpreter_id = auth.uid()
    )
    OR assigned_interpreter_id = auth.uid()
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  );

CREATE POLICY "routing_queue_insert_requester" ON public.routing_queue
  FOR INSERT
  WITH CHECK (
    request_id IN (
      SELECT id FROM public.interpreter_requests
      WHERE requester_id = auth.uid()
    )
  );

CREATE POLICY "routing_queue_update_participants" ON public.routing_queue
  FOR UPDATE
  USING (
    request_id IN (
      SELECT id FROM public.interpreter_requests
      WHERE requester_id = auth.uid()
         OR accepted_by = auth.uid()
         OR matched_interpreter_id = auth.uid()
    )
    OR assigned_interpreter_id = auth.uid()
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  )
  WITH CHECK (
    request_id IN (
      SELECT id FROM public.interpreter_requests
      WHERE requester_id = auth.uid()
         OR accepted_by = auth.uid()
         OR matched_interpreter_id = auth.uid()
    )
    OR assigned_interpreter_id = auth.uid()
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  );

-- phone_calls policies
DROP POLICY IF EXISTS "Service role can manage calls" ON public.phone_calls;
DROP POLICY IF EXISTS "callers can insert calls" ON public.phone_calls;
DROP POLICY IF EXISTS "callers can update calls" ON public.phone_calls;
DROP POLICY IF EXISTS "callers can delete calls" ON public.phone_calls;

CREATE POLICY "callers can insert calls" ON public.phone_calls
  FOR INSERT
  WITH CHECK (caller_id = auth.uid());

CREATE POLICY "callers can update calls" ON public.phone_calls
  FOR UPDATE
  USING (caller_id = auth.uid())
  WITH CHECK (caller_id = auth.uid());

CREATE POLICY "callers can delete calls" ON public.phone_calls
  FOR DELETE
  USING (caller_id = auth.uid());
