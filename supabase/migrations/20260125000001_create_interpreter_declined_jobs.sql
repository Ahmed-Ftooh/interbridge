-- Create interpreter_declined_jobs table
-- Tracks which interpreters have declined which requests
-- so declined requests are hidden from that specific interpreter
CREATE TABLE IF NOT EXISTS public.interpreter_declined_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interpreter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id UUID NOT NULL REFERENCES public.interpreter_requests(id) ON DELETE CASCADE,
  declined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(interpreter_id, request_id)
);

-- Enable RLS
ALTER TABLE public.interpreter_declined_jobs ENABLE ROW LEVEL SECURITY;

-- Interpreters can view their own declined jobs
CREATE POLICY "Interpreters can view own declined jobs"
  ON public.interpreter_declined_jobs
  FOR SELECT
  USING (auth.uid() = interpreter_id);

-- Interpreters can insert their own declined jobs
CREATE POLICY "Interpreters can insert own declined jobs"
  ON public.interpreter_declined_jobs
  FOR INSERT
  WITH CHECK (auth.uid() = interpreter_id);

-- Interpreters can delete their own declined jobs
CREATE POLICY "Interpreters can delete own declined jobs"
  ON public.interpreter_declined_jobs
  FOR DELETE
  USING (auth.uid() = interpreter_id);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_declined_jobs_interpreter
  ON public.interpreter_declined_jobs(interpreter_id);

CREATE INDEX IF NOT EXISTS idx_declined_jobs_request
  ON public.interpreter_declined_jobs(request_id);
