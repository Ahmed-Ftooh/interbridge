-- Ensure interpreter_certificates table exists and has proper RLS policies
-- This table stores metadata about uploaded certificates (files in 'interpreter_certificates' storage bucket)

CREATE TABLE IF NOT EXISTS public.interpreter_certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  url text,
  storage_path text NOT NULL,
  certificate_type text NOT NULL,
  issuing_organization text,
  expiration_date timestamptz,
  file_size integer,
  file_name text,
  uploaded_at timestamptz DEFAULT now(),
  is_verified boolean DEFAULT false,
  status text DEFAULT 'pending',
  review_note text,
  reviewed_at timestamptz
);

-- Enable RLS
ALTER TABLE public.interpreter_certificates ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS interpreter_certificates_select ON public.interpreter_certificates;
DROP POLICY IF EXISTS interpreter_certificates_insert ON public.interpreter_certificates;
DROP POLICY IF EXISTS interpreter_certificates_update ON public.interpreter_certificates;
DROP POLICY IF EXISTS interpreter_certificates_delete ON public.interpreter_certificates;

-- Users can read their own certificates
CREATE POLICY interpreter_certificates_select ON public.interpreter_certificates
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin());

-- Users can insert their own certificates
CREATE POLICY interpreter_certificates_insert ON public.interpreter_certificates
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own certificates, admins can update any
CREATE POLICY interpreter_certificates_update ON public.interpreter_certificates
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin());

-- Only admins can delete certificates
CREATE POLICY interpreter_certificates_delete ON public.interpreter_certificates
  FOR DELETE USING (public.is_admin());

-- Ensure voice_samples table exists for metadata (files in 'voice_samples' storage bucket)
CREATE TABLE IF NOT EXISTS public.voice_samples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  url text,
  prompt text,
  sentence_type text DEFAULT 'onboarding',
  file_size integer,
  created_at timestamptz DEFAULT now(),
  is_verified boolean DEFAULT false
);

-- Enable RLS
ALTER TABLE public.voice_samples ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS voice_samples_select ON public.voice_samples;
DROP POLICY IF EXISTS voice_samples_insert ON public.voice_samples;
DROP POLICY IF EXISTS voice_samples_update ON public.voice_samples;
DROP POLICY IF EXISTS voice_samples_delete ON public.voice_samples;

-- Users can read their own voice samples
CREATE POLICY voice_samples_select ON public.voice_samples
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin());

-- Users can insert their own voice samples
CREATE POLICY voice_samples_insert ON public.voice_samples
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own, admins can update any
CREATE POLICY voice_samples_update ON public.voice_samples
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin());

-- Only admins can delete
CREATE POLICY voice_samples_delete ON public.voice_samples
  FOR DELETE USING (public.is_admin());
