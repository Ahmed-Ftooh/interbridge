-- Create translation drafts table for interpreter autosaves

CREATE TABLE IF NOT EXISTS public.translation_drafts (
  request_id uuid NOT NULL REFERENCES public.document_translation_requests(id) ON DELETE CASCADE,
  interpreter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  draft_text text,
  draft_file_url text,
  autosaved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (request_id, interpreter_id)
);

CREATE INDEX IF NOT EXISTS idx_translation_drafts_request_id
  ON public.translation_drafts(request_id);

CREATE INDEX IF NOT EXISTS idx_translation_drafts_interpreter_id
  ON public.translation_drafts(interpreter_id);

ALTER TABLE public.translation_drafts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS translation_drafts_select ON public.translation_drafts;
DROP POLICY IF EXISTS translation_drafts_insert ON public.translation_drafts;
DROP POLICY IF EXISTS translation_drafts_update ON public.translation_drafts;
DROP POLICY IF EXISTS translation_drafts_delete ON public.translation_drafts;

CREATE POLICY translation_drafts_select ON public.translation_drafts
  FOR SELECT
  USING (
    interpreter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.document_translation_requests d
      WHERE d.id = translation_drafts.request_id
        AND d.accepted_by = auth.uid()
    )
  );

CREATE POLICY translation_drafts_insert ON public.translation_drafts
  FOR INSERT
  WITH CHECK (
    interpreter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.document_translation_requests d
      WHERE d.id = translation_drafts.request_id
        AND d.accepted_by = auth.uid()
    )
  );

CREATE POLICY translation_drafts_update ON public.translation_drafts
  FOR UPDATE
  USING (
    interpreter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.document_translation_requests d
      WHERE d.id = translation_drafts.request_id
        AND d.accepted_by = auth.uid()
    )
  )
  WITH CHECK (
    interpreter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.document_translation_requests d
      WHERE d.id = translation_drafts.request_id
        AND d.accepted_by = auth.uid()
    )
  );

CREATE POLICY translation_drafts_delete ON public.translation_drafts
  FOR DELETE
  USING (
    interpreter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.document_translation_requests d
      WHERE d.id = translation_drafts.request_id
        AND d.accepted_by = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.translation_drafts TO authenticated;
