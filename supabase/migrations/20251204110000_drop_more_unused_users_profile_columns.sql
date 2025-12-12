-- Drop additional unused columns from users_profile
ALTER TABLE public.users_profile
  DROP COLUMN IF EXISTS deleted_at,
  DROP COLUMN IF EXISTS level,
  DROP COLUMN IF EXISTS general_certificate_url,
  DROP COLUMN IF EXISTS medical_certificate_url,
  DROP COLUMN IF EXISTS shifts,
  DROP COLUMN IF EXISTS medical_test_score,
  DROP COLUMN IF EXISTS application_status,
  DROP COLUMN IF EXISTS minutes_volunteered,
  DROP COLUMN IF EXISTS experience_years,
  DROP COLUMN IF EXISTS interpreter_level,
  DROP COLUMN IF EXISTS shift_availability,
  DROP COLUMN IF EXISTS medical_test_duration_seconds,
  DROP COLUMN IF EXISTS medical_test_passed,
  DROP COLUMN IF EXISTS volunteer_minutes_accumulated,
  DROP COLUMN IF EXISTS last_application_id;
