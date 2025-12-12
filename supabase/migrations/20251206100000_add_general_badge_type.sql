-- Add 'general' to medical_section_type enum for general quiz badges
-- This allows the interpreter_badges table to store both medical and general badges

-- Add 'general' value to the enum if it doesn't exist
DO $$
BEGIN
  -- Check if 'general' already exists in the enum
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'general' 
    AND enumtypid = 'medical_section_type'::regtype
  ) THEN
    ALTER TYPE medical_section_type ADD VALUE 'general';
  END IF;
END $$;
