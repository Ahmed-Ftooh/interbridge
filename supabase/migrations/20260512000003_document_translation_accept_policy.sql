-- Allow interpreters to accept pending document translation requests

ALTER TABLE public.document_translation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Interpreters can accept document translation requests"
  ON public.document_translation_requests;

CREATE POLICY "Interpreters can accept document translation requests"
  ON public.document_translation_requests
  FOR UPDATE
  USING (status = 'pending' AND accepted_by IS NULL)
  WITH CHECK (accepted_by = auth.uid() AND status = 'accepted');
