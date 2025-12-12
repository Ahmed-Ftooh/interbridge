-- Migration: Drop unused columns from users_profile table
-- These columns are not used in the application code

-- Drop unused columns from users_profile
ALTER TABLE public.users_profile
  DROP COLUMN IF EXISTS voice_sample_url,
  DROP COLUMN IF EXISTS verified_medical_sections,
  DROP COLUMN IF EXISTS completed_medical_quizzes,
  DROP COLUMN IF EXISTS medical_quiz_results,
  DROP COLUMN IF EXISTS medical_quiz_passed,
  DROP COLUMN IF EXISTS quiz_attempts,
  DROP COLUMN IF EXISTS badge_ids,
  DROP COLUMN IF EXISTS certificate_urls,
  DROP COLUMN IF EXISTS languages,
  DROP COLUMN IF EXISTS quiz_status,
  DROP COLUMN IF EXISTS first_name,
  DROP COLUMN IF EXISTS last_name;

-- Note: The following columns are STILL IN USE and should NOT be deleted:
-- user_id, username, role, profile_image, gender, country, created_at,
-- institution_id, employment_type, experience_years, interpreter_level,
-- shift_availability, general_certificate_url, medical_certificate_url,
-- medical_test_score, medical_test_duration_seconds, medical_test_passed,
-- volunteer_minutes_accumulated, last_application_id
