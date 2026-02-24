-- Fix: ON CONFLICT (user_id, quiz_type, medical_section) fails because
-- the table only has PARTIAL unique indexes (with WHERE clauses).
-- PostgreSQL requires a non-partial unique index matching the ON CONFLICT columns.
-- Replace the two partial indexes with a single universal unique index
-- using NULLS NOT DISTINCT (PG15+) so NULL medical_section is treated as equal.

-- Drop the two partial indexes
DROP INDEX IF EXISTS quiz_attempts_user_quiz_general_unique;
DROP INDEX IF EXISTS quiz_attempts_user_quiz_section_unique;

-- Create a single non-partial unique index that covers both cases
CREATE UNIQUE INDEX quiz_attempts_user_quiz_section_unique
  ON public.quiz_attempts (user_id, quiz_type, medical_section)
  NULLS NOT DISTINCT;
