-- Migration: Add bio and years_experience fields to interpreter_details
-- Safe (idempotent) checks
ALTER TABLE interpreter_details ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE interpreter_details ADD COLUMN IF NOT EXISTS years_experience INT;

-- Optional: Ensure existing rows have null defaults (already implicit)
-- UPDATE interpreter_details SET years_experience = 0 WHERE years_experience IS NULL; -- Uncomment if you prefer 0 instead of NULL

-- Recommended constraint: non-negative years
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'interpreter_details_years_experience_non_negative'
  ) THEN
    ALTER TABLE interpreter_details
      ADD CONSTRAINT interpreter_details_years_experience_non_negative
      CHECK (years_experience IS NULL OR years_experience >= 0);
  END IF;
END $$;

-- (Optional) index if querying by years_experience
-- CREATE INDEX IF NOT EXISTS idx_interpreter_details_years_experience ON interpreter_details (years_experience);

-- RLS extension for upcoming private onboarding bucket usage is handled separately.