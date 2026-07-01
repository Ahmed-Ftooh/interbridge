-- Tighten storage policies for voice_samples and government-ids

UPDATE storage.buckets
SET public = false
WHERE id IN ('voice_samples', 'government-ids');

-- Drop old policies
DROP POLICY IF EXISTS "voice_samples_owner" ON storage.objects;
DROP POLICY IF EXISTS "voice_samples_admin_read" ON storage.objects;
DROP POLICY IF EXISTS "Admin can read all government ids" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own government ids" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own government ids" ON storage.objects;

-- Drop new policy names if they already exist
DROP POLICY IF EXISTS "voice_samples_select_owner" ON storage.objects;
DROP POLICY IF EXISTS "voice_samples_select_admin" ON storage.objects;
DROP POLICY IF EXISTS "voice_samples_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "voice_samples_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "voice_samples_delete_admin" ON storage.objects;

DROP POLICY IF EXISTS "government_ids_select_owner" ON storage.objects;
DROP POLICY IF EXISTS "government_ids_select_admin" ON storage.objects;
DROP POLICY IF EXISTS "government_ids_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "government_ids_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "government_ids_delete_admin" ON storage.objects;

-- Voice samples: owners can read/write; admins can read/delete
CREATE POLICY "voice_samples_select_owner" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'voice_samples' AND auth.uid() = owner);

CREATE POLICY "voice_samples_select_admin" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'voice_samples' AND public.is_admin());

CREATE POLICY "voice_samples_insert_owner" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'voice_samples' AND auth.uid() = owner);

CREATE POLICY "voice_samples_update_owner" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'voice_samples' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'voice_samples' AND auth.uid() = owner);

CREATE POLICY "voice_samples_delete_admin" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'voice_samples' AND public.is_admin());

-- Government IDs: owners can read/write; admins can read/delete
CREATE POLICY "government_ids_select_owner" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'government-ids' AND auth.uid() = owner);

CREATE POLICY "government_ids_select_admin" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'government-ids' AND public.is_admin());

CREATE POLICY "government_ids_insert_owner" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'government-ids' AND auth.uid() = owner);

CREATE POLICY "government_ids_update_owner" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'government-ids' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'government-ids' AND auth.uid() = owner);

CREATE POLICY "government_ids_delete_admin" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'government-ids' AND public.is_admin());
