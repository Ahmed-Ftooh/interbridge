-- Add country column to users_profile table
ALTER TABLE public.users_profile
ADD COLUMN IF NOT EXISTS country text;

-- Add comment for documentation
COMMENT ON COLUMN public.users_profile.country IS 'User country (e.g., US, UK, EG)';
