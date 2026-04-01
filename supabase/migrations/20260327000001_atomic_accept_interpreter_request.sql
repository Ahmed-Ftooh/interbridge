BEGIN;

-- Atomic accept for interpreter requests.
-- Returns the accepted request row as jsonb, or NULL if another interpreter won.
CREATE OR REPLACE FUNCTION public.accept_interpreter_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.interpreter_requests%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.interpreter_requests
  SET
    status = 'accepted',
    accepted_by = v_user_id,
    accepted_at = now(),
    updated_at = now()
  WHERE id = p_request_id
    AND status = 'pending'
    AND accepted_by IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN to_jsonb(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.accept_interpreter_request(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_interpreter_request(uuid) TO authenticated;

-- Helps pending-request catch-up and list queries used by web incoming flow.
CREATE INDEX IF NOT EXISTS idx_interpreter_requests_pending_lang_created
  ON public.interpreter_requests (from_language, to_language, created_at DESC)
  WHERE status = 'pending';

COMMIT;
