-- Add missing file_name and file_type columns to document_translation_requests table
-- This migration is for tables that were created without these columns

-- Check if columns exist before adding them
DO $$
BEGIN
    -- Add file_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'document_translation_requests' 
        AND column_name = 'file_name'
    ) THEN
        ALTER TABLE public.document_translation_requests 
        ADD COLUMN file_name TEXT;
        RAISE NOTICE 'Added file_name column';
    ELSE
        RAISE NOTICE 'file_name column already exists';
    END IF;

    -- Add file_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'document_translation_requests' 
        AND column_name = 'file_type'
    ) THEN
        ALTER TABLE public.document_translation_requests 
        ADD COLUMN file_type TEXT;
        RAISE NOTICE 'Added file_type column';
    ELSE
        RAISE NOTICE 'file_type column already exists';
    END IF;
END $$;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'document_translation_requests'
AND column_name IN ('file_name', 'file_type')
ORDER BY column_name;

