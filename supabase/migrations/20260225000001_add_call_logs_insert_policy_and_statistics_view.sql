-- Allow authenticated users to INSERT into call_logs when they are the interpreter
CREATE POLICY "Interpreters can insert own call logs"
  ON public.call_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (interpreter_id = auth.uid());

-- Allow the interpreter to also UPDATE their own call logs
CREATE POLICY "Interpreters can update own call logs"
  ON public.call_logs
  FOR UPDATE
  TO authenticated
  USING (interpreter_id = auth.uid())
  WITH CHECK (interpreter_id = auth.uid());

-- Recreate call_statistics view with last_call_at column
DROP VIEW IF EXISTS public.call_statistics;
CREATE VIEW public.call_statistics AS
  SELECT
    user_id,
    COUNT(*)::int                              AS total_calls,
    COALESCE(SUM(duration_seconds), 0)::int    AS total_duration_seconds,
    COALESCE(AVG(duration_seconds), 0)::int    AS average_duration_seconds,
    MIN(started_at)                            AS first_call,
    MAX(ended_at)                              AS last_call,
    MAX(created_at)                            AS last_call_at
  FROM public.call_sessions
  GROUP BY user_id;
