-- Add verification status to organizations table
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS verification_status text DEFAULT 'pending' 
CHECK (verification_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS verified_at timestamptz;

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES auth.users(id);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS rejection_reason text;

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS description text;

-- Create table for organization verification documents
CREATE TABLE IF NOT EXISTS public.organization_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_type text NOT NULL CHECK (document_type IN ('business_license', 'registration_certificate', 'additional')),
  storage_path text NOT NULL,
  file_name text,
  file_size bigint,
  uploaded_at timestamptz DEFAULT now(),
  uploaded_by uuid REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.organization_documents ENABLE ROW LEVEL SECURITY;

-- RLS policies for organization_documents
CREATE POLICY organization_documents_select ON public.organization_documents
FOR SELECT
TO authenticated
USING (
  organization_id IN (
    SELECT om.organization_id FROM organization_members om WHERE om.user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM users_profile up
    WHERE up.user_id = auth.uid()
    AND up.role IN ('admin', 'superadmin')
  )
);

CREATE POLICY organization_documents_insert ON public.organization_documents
FOR INSERT
TO authenticated
WITH CHECK (
  uploaded_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM users_profile up
    WHERE up.user_id = auth.uid()
    AND up.role IN ('admin', 'superadmin', 'organization_admin')
  )
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS organization_documents_org_id_idx ON public.organization_documents(organization_id);

-- Create storage bucket for documents if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for documents bucket
CREATE POLICY "Authenticated users can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

CREATE POLICY "Users can view their organization documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' 
  AND (
    -- User is organization member
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.user_id = auth.uid()
      AND storage.foldername(name)[1] = 'organization_documents'
      AND storage.foldername(name)[2] = om.organization_id::text
    )
    OR
    -- User is admin
    EXISTS (
      SELECT 1 FROM users_profile up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('admin', 'superadmin')
    )
  )
);
