-- Migration: Auto-create user profile on auth.users insert
-- This ensures every user gets a profile even if the client-side creation fails

-- Create a function that creates a user profile when a new user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert a basic profile for the new user
  -- The role will default to 'requester' and can be updated later by finalizePendingRegistrationData
  INSERT INTO public.users_profile (user_id, username, role, profile_image, gender)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'requester'),
    '',
    ''
  )
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- Create the trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Also create profiles for any existing users who don't have one
INSERT INTO public.users_profile (user_id, username, role, profile_image, gender)
SELECT 
  u.id,
  COALESCE(u.raw_user_meta_data->>'username', ''),
  COALESCE(u.raw_user_meta_data->>'role', 'requester'),
  '',
  ''
FROM auth.users u
LEFT JOIN public.users_profile p ON u.id = p.user_id
WHERE p.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;
