-- Move employment_type from users_profile to interpreter_details
-- This is more appropriate since only interpreters have employment types

-- Step 1: Add employment_type column to interpreter_details
ALTER TABLE public.interpreter_details
ADD COLUMN IF NOT EXISTS employment_type text CHECK (employment_type IN ('volunteer', 'paid'));

-- Step 2: Copy existing employment_type values from users_profile to interpreter_details
UPDATE public.interpreter_details id
SET employment_type = up.employment_type
FROM public.users_profile up
WHERE id.user_id = up.user_id
AND up.employment_type IS NOT NULL;

-- Step 3: Set default for interpreters who don't have it set
UPDATE public.interpreter_details
SET employment_type = 'volunteer'
WHERE employment_type IS NULL;

-- Add comment
COMMENT ON COLUMN public.interpreter_details.employment_type IS 'Interpreter employment type: volunteer or paid';

-- Note: We keep the column in users_profile for now to avoid breaking existing code
-- It can be removed in a future migration after all code is updated
