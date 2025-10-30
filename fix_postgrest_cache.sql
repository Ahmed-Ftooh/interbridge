-- This script helps fix PostgREST schema cache issues
-- Run this in your Supabase SQL Editor after adding columns

-- Step 1: Verify the columns exist
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'document_translation_requests' 
AND column_name IN ('file_name', 'file_type')
ORDER BY column_name;

-- Step 2: Add a comment to force PostgREST to refresh its cache
-- This triggers a schema reload
DO $$
BEGIN
    -- Add comments to the columns to force cache refresh
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'document_translation_requests' 
        AND column_name = 'file_name'
    ) THEN
        COMMENT ON COLUMN public.document_translation_requests.file_name IS 'Original filename of uploaded document';
        RAISE NOTICE 'Added comment to file_name column';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'document_translation_requests' 
        AND column_name = 'file_type'
    ) THEN
        COMMENT ON COLUMN public.document_translation_requests.file_type IS 'MIME type of uploaded file';
        RAISE NOTICE 'Added comment to file_type column';
    END IF;
END $$;

-- Step 3: Verify all required columns exist
SELECT column_name
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'document_translation_requests'
ORDER BY ordinal_position;

