-- Tighten storage policies for documents and profiles

-- Ensure documents bucket is private
UPDATE storage.buckets
SET public = false
WHERE id = 'documents';

-- Drop overly-broad documents policies
DROP POLICY IF EXISTS "user can add its doucment flreew_0" ON storage.objects;
DROP POLICY IF EXISTS "user can add its doucment flreew_1" ON storage.objects;
DROP POLICY IF EXISTS "user can add its doucment flreew_2" ON storage.objects;
DROP POLICY IF EXISTS "user can add its doucment flreew_3" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their organization documents" ON storage.objects;
DROP POLICY IF EXISTS "documents_read_access" ON storage.objects;
DROP POLICY IF EXISTS "documents_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "documents_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "documents_delete_owner" ON storage.objects;

-- Documents: read access for request participants, org admins, and platform admins
CREATE POLICY "documents_read_access" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (
      is_admin()
      OR auth.uid() = owner
      OR EXISTS (
        SELECT 1
        FROM public.document_translation_requests d
        WHERE (d.requester_id = auth.uid() OR d.accepted_by = auth.uid())
          AND (
            (d.file_url IS NOT NULL AND d.file_url LIKE '%' || name)
            OR (d.translated_file_url IS NOT NULL AND d.translated_file_url LIKE '%' || name)
          )
      )
      OR (
        (storage.foldername(name))[1] = 'organization_documents'
        AND (storage.foldername(name))[2] IN (
          SELECT organization_id::text
          FROM public.organization_members
          WHERE user_id = auth.uid() AND role = 'organization_admin'
        )
      )
    )
  );

-- Documents: insert only into expected paths
CREATE POLICY "documents_insert_owner" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'documents'
    AND (
      (
        (storage.foldername(name))[1] IN ('requests', 'translated')
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'organization_documents'
        AND (storage.foldername(name))[2] IN (
          SELECT organization_id::text
          FROM public.organization_members
          WHERE user_id = auth.uid() AND role = 'organization_admin'
        )
      )
    )
  );

-- Documents: update/delete limited to owner or org admins
CREATE POLICY "documents_update_owner" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (
      auth.uid() = owner
      OR is_admin()
      OR (
        (storage.foldername(name))[1] = 'organization_documents'
        AND (storage.foldername(name))[2] IN (
          SELECT organization_id::text
          FROM public.organization_members
          WHERE user_id = auth.uid() AND role = 'organization_admin'
        )
      )
    )
  )
  WITH CHECK (
    bucket_id = 'documents'
    AND (
      auth.uid() = owner
      OR is_admin()
      OR (
        (storage.foldername(name))[1] = 'organization_documents'
        AND (storage.foldername(name))[2] IN (
          SELECT organization_id::text
          FROM public.organization_members
          WHERE user_id = auth.uid() AND role = 'organization_admin'
        )
      )
    )
  );

CREATE POLICY "documents_delete_owner" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'documents'
    AND (
      auth.uid() = owner
      OR is_admin()
      OR (
        (storage.foldername(name))[1] = 'organization_documents'
        AND (storage.foldername(name))[2] IN (
          SELECT organization_id::text
          FROM public.organization_members
          WHERE user_id = auth.uid() AND role = 'organization_admin'
        )
      )
    )
  );

-- Drop overly-broad profiles policies
DROP POLICY IF EXISTS "used can handle its own profile 1ige2ga_0" ON storage.objects;
DROP POLICY IF EXISTS "used can handle its own profile 1ige2ga_1" ON storage.objects;
DROP POLICY IF EXISTS "used can handle its own profile 1ige2ga_2" ON storage.objects;
DROP POLICY IF EXISTS "used can handle its own profile 1ige2ga_3" ON storage.objects;
DROP POLICY IF EXISTS "profiles_read_access" ON storage.objects;
DROP POLICY IF EXISTS "profiles_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "profiles_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "profiles_delete_owner" ON storage.objects;

-- Profiles: restrict writes to owners; read allowed for authenticated (bucket is public)
CREATE POLICY "profiles_read_access" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'profiles');

CREATE POLICY "profiles_insert_owner" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'profiles' AND auth.uid() = owner);

CREATE POLICY "profiles_update_owner" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'profiles' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'profiles' AND auth.uid() = owner);

CREATE POLICY "profiles_delete_owner" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'profiles' AND auth.uid() = owner);
