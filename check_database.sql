-- Quick database check script
-- Run this in your Supabase SQL Editor to verify your database is set up correctly

-- Check if document_translation_requests table exists
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'document_translation_requests'
) AS table_exists;

-- If the above returns false, the table doesn't exist and you need to run the migration

-- Check if languages table exists
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'languages'
) AS languages_table_exists;

-- If the above returns false, you need to create the languages table

-- Check if languages table has data
SELECT COUNT(*) as language_count FROM languages;

-- If this returns 0, you need to populate the languages table

-- Check if document_translation_requests has the correct columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'document_translation_requests'
ORDER BY ordinal_position;

-- You should see: id, requester_id, from_language, to_language, specialization, 
-- text, title, comment, translation_method, file_url, file_type, file_name, 
-- status, accepted_by, accepted_at, completed_at, created_at, translated_text, 
-- translated_file_url

