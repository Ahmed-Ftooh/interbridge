-- Migration: Call Request System with Ring-All Logic
-- Date: 2025-11-29
-- Description: Adds call_requests table for ring-all-interpreters functionality

BEGIN;

-- ============================================
-- CALL REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.call_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  interpreter_id uuid REFERENCES auth.users(id), -- NULL until accepted
  organization_id uuid REFERENCES public.organizations(id),
  from_language text NOT NULL,
  to_language text NOT NULL,
  specialization text,
  status text NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing', 'accepted', 'completed', 'cancelled', 'no_interpreters', 'timeout')),
  channel_id text, -- Agora channel ID
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS call_requests_caller_idx ON public.call_requests(caller_id);
CREATE INDEX IF NOT EXISTS call_requests_interpreter_idx ON public.call_requests(interpreter_id);
CREATE INDEX IF NOT EXISTS call_requests_status_idx ON public.call_requests(status);
CREATE INDEX IF NOT EXISTS call_requests_org_idx ON public.call_requests(organization_id);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS call_requests_set_updated_at ON public.call_requests;
CREATE TRIGGER call_requests_set_updated_at
BEFORE UPDATE ON public.call_requests
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ============================================
-- CALL DECLINES (for analytics)
-- ============================================
CREATE TABLE IF NOT EXISTS public.call_declines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_request_id uuid NOT NULL REFERENCES public.call_requests(id) ON DELETE CASCADE,
  interpreter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  declined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(call_request_id, interpreter_id)
);

CREATE INDEX IF NOT EXISTS call_declines_interpreter_idx ON public.call_declines(interpreter_id);

-- ============================================
-- CALL LOGS UPDATE
-- ============================================
ALTER TABLE public.call_logs
  ADD COLUMN IF NOT EXISTS call_request_id uuid REFERENCES public.call_requests(id);

-- ============================================
-- VOLUNTEER MINUTES TRACKING
-- ============================================
ALTER TABLE public.interpreter_details
  ADD COLUMN IF NOT EXISTS total_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS volunteer_goal_minutes integer NOT NULL DEFAULT 12000,
  ADD COLUMN IF NOT EXISTS volunteer_goal_reached_at timestamptz;

-- Function to increment interpreter minutes
CREATE OR REPLACE FUNCTION public.increment_interpreter_minutes(
  interpreter_user_id uuid,
  minutes_to_add integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_total integer;
  goal_minutes integer;
BEGIN
  UPDATE public.interpreter_details
  SET total_minutes = total_minutes + minutes_to_add
  WHERE user_id = interpreter_user_id
  RETURNING total_minutes, volunteer_goal_minutes INTO new_total, goal_minutes;

  -- Check if goal reached for the first time
  IF new_total >= goal_minutes THEN
    UPDATE public.interpreter_details
    SET volunteer_goal_reached_at = now()
    WHERE user_id = interpreter_user_id
      AND volunteer_goal_reached_at IS NULL;
  END IF;
END;
$$;

-- Function to deduct from organization wallet
CREATE OR REPLACE FUNCTION public.deduct_organization_wallet(
  org_id uuid,
  amount decimal
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.organizations
  SET wallet_balance = wallet_balance - amount
  WHERE id = org_id;
END;
$$;

-- ============================================
-- RLS POLICIES
-- ============================================
ALTER TABLE public.call_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_declines ENABLE ROW LEVEL SECURITY;

-- Call requests: caller can see own, interpreters can see ringing calls
DROP POLICY IF EXISTS "call_requests_caller" ON public.call_requests;
CREATE POLICY "call_requests_caller"
  ON public.call_requests
  FOR ALL
  USING (
    caller_id = auth.uid() 
    OR interpreter_id = auth.uid()
    OR (status = 'ringing' AND EXISTS (
      SELECT 1 FROM public.interpreter_details WHERE user_id = auth.uid() AND is_verified = true
    ))
    OR public.is_admin()
  )
  WITH CHECK (
    caller_id = auth.uid() 
    OR interpreter_id = auth.uid()
    OR public.is_admin()
  );

-- Call declines: interpreter can insert own
DROP POLICY IF EXISTS "call_declines_self" ON public.call_declines;
CREATE POLICY "call_declines_self"
  ON public.call_declines
  FOR INSERT
  WITH CHECK (interpreter_id = auth.uid());

DROP POLICY IF EXISTS "call_declines_view" ON public.call_declines;
CREATE POLICY "call_declines_view"
  ON public.call_declines
  FOR SELECT
  USING (interpreter_id = auth.uid() OR public.is_admin());

-- ============================================
-- ADMIN INTERPRETER MESSAGES (Updated table name)
-- ============================================
-- Drop old table if exists and create with correct name
DROP TABLE IF EXISTS public.admin_interpreter_messages CASCADE;

CREATE TABLE IF NOT EXISTS public.admin_interpreter_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interpreter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  message text NOT NULL,
  from_admin boolean NOT NULL DEFAULT true,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_interpreter_messages_interpreter_idx ON public.admin_interpreter_messages(interpreter_id);
CREATE INDEX IF NOT EXISTS admin_interpreter_messages_created_idx ON public.admin_interpreter_messages(created_at DESC);

ALTER TABLE public.admin_interpreter_messages ENABLE ROW LEVEL SECURITY;

-- Admins can manage all, interpreters can view/create own messages
DROP POLICY IF EXISTS "admin_messages_access" ON public.admin_interpreter_messages;
CREATE POLICY "admin_messages_access"
  ON public.admin_interpreter_messages
  FOR ALL
  USING (
    interpreter_id = auth.uid() 
    OR admin_id = auth.uid()
    OR public.is_admin()
  )
  WITH CHECK (
    interpreter_id = auth.uid() 
    OR public.is_admin()
  );

-- ============================================
-- QUIZ SECTIONS TABLE (standalone questions)
-- ============================================
CREATE TABLE IF NOT EXISTS public.quiz_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section text NOT NULL CHECK (section IN ('general', 'neurology', 'cardiology', 'emergency', 'oncology', 'psychiatry', 'internal_medicine')),
  prompt text NOT NULL,
  options jsonb NOT NULL,
  correct_option text NOT NULL,
  time_limit_seconds integer NOT NULL DEFAULT 30,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS quiz_sections_section_idx ON public.quiz_sections(section);
CREATE INDEX IF NOT EXISTS quiz_sections_active_idx ON public.quiz_sections(is_active) WHERE is_active = true;

ALTER TABLE public.quiz_sections ENABLE ROW LEVEL SECURITY;

-- Anyone can read active questions, only admins can manage
DROP POLICY IF EXISTS "quiz_sections_read" ON public.quiz_sections;
CREATE POLICY "quiz_sections_read"
  ON public.quiz_sections
  FOR SELECT
  USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "quiz_sections_admin" ON public.quiz_sections;
CREATE POLICY "quiz_sections_admin"
  ON public.quiz_sections
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Insert sample quiz questions
INSERT INTO public.quiz_sections (section, prompt, options, correct_option, time_limit_seconds) VALUES
-- General
('general', 'During a remote call a nurse asks you to translate a medication dosage. What is your priority?', 
 '["Translate verbatim without confirming context", "Clarify measurement units before relaying the dosage", "Skip the dosage and focus on patient comfort", "Ask the patient to look up the dosage later"]',
 'Clarify measurement units before relaying the dosage', 30),
('general', 'A patient discloses new symptoms directly to you while the doctor steps away. What should you do?',
 '["Wait to mention it until the session ends", "Document it for yourself only", "Immediately interpret the message once the provider returns", "Offer medical advice to the patient"]',
 'Immediately interpret the message once the provider returns', 30),
('general', 'The provider uses a complex acronym the patient does not understand. What is the correct protocol?',
 '["Explain the acronym yourself", "Ask the provider to restate or explain before interpreting", "Ignore it to keep the call short", "Translate only part of the sentence"]',
 'Ask the provider to restate or explain before interpreting', 30),

-- Neurology
('neurology', 'What is the primary function of the blood-brain barrier in neurological contexts?',
 '["To produce cerebrospinal fluid", "To protect the brain from harmful substances in the blood", "To regulate body temperature", "To control muscle movement"]',
 'To protect the brain from harmful substances in the blood', 30),
('neurology', 'When interpreting for a stroke patient, which term describes weakness on one side of the body?',
 '["Hemiplegia", "Quadriplegia", "Paraplegia", "Monoplegia"]',
 'Hemiplegia', 30),
('neurology', 'What does "aphasia" mean when interpreting for neurology patients?',
 '["Memory loss", "Difficulty with language and speech", "Muscle weakness", "Vision problems"]',
 'Difficulty with language and speech', 30),

-- Cardiology
('cardiology', 'What does "tachycardia" mean in medical terminology?',
 '["Slow heart rate", "Fast heart rate", "Irregular heart rhythm", "Heart muscle weakness"]',
 'Fast heart rate', 30),
('cardiology', 'When interpreting for a cardiac patient, what does "angina pectoris" refer to?',
 '["Chest pain due to reduced blood flow to the heart", "Heart attack", "Irregular heartbeat", "High blood pressure"]',
 'Chest pain due to reduced blood flow to the heart', 30),
('cardiology', 'What is "bradycardia" in medical terminology?',
 '["Fast heart rate", "Slow heart rate", "Irregular heartbeat", "Heart failure"]',
 'Slow heart rate', 30),

-- Emergency
('emergency', 'In emergency interpretation, what does "triage" refer to?',
 '["A type of medication", "Sorting patients by urgency of care", "Hospital admission process", "Medical billing code"]',
 'Sorting patients by urgency of care', 30),
('emergency', 'What is the correct interpretation for "STAT" in medical orders?',
 '["Take with food", "Immediately/urgent", "Once daily", "As needed"]',
 'Immediately/urgent', 30),
('emergency', 'What does "code blue" typically mean in a hospital setting?',
 '["Visitor arriving", "Cardiac or respiratory arrest", "Fire drill", "Patient discharge"]',
 'Cardiac or respiratory arrest', 30),

-- Oncology
('oncology', 'What does "metastasis" mean when interpreting for oncology patients?',
 '["Cancer cure", "Cancer spreading to other parts of the body", "Tumor removal", "Chemotherapy side effect"]',
 'Cancer spreading to other parts of the body', 30),
('oncology', 'What is "palliative care" in oncology context?',
 '["Curative treatment", "Care focused on comfort and quality of life", "Surgical intervention", "Radiation therapy"]',
 'Care focused on comfort and quality of life', 30),
('oncology', 'What does "remission" mean in cancer treatment?',
 '["Cancer is spreading", "Signs and symptoms of cancer have reduced or disappeared", "Cancer has returned", "Treatment has failed"]',
 'Signs and symptoms of cancer have reduced or disappeared', 30),

-- Psychiatry
('psychiatry', 'What does "affect" mean in psychiatric terminology?',
 '["To influence something", "Outward expression of emotion", "A type of medication", "Memory function"]',
 'Outward expression of emotion', 30),
('psychiatry', 'When interpreting for a psychiatric evaluation, what does "ideation" typically refer to?',
 '["Creative thinking", "Formation of ideas or thoughts, often about self-harm", "Normal thought process", "Memory recall"]',
 'Formation of ideas or thoughts, often about self-harm', 30),
('psychiatry', 'What is "anhedonia" in psychiatric context?',
 '["Excessive happiness", "Inability to feel pleasure", "Fear of crowds", "Memory problems"]',
 'Inability to feel pleasure', 30),

-- Internal Medicine
('internal_medicine', 'What does "dyspnea" mean in medical terminology?',
 '["Difficulty swallowing", "Difficulty breathing", "Difficulty speaking", "Difficulty walking"]',
 'Difficulty breathing', 30),
('internal_medicine', 'When interpreting for a diabetes patient, what does "hyperglycemia" indicate?',
 '["Low blood sugar", "High blood sugar", "Normal blood sugar", "Blood sugar fluctuation"]',
 'High blood sugar', 30),
('internal_medicine', 'What does "edema" mean in medical terminology?',
 '["Skin rash", "Swelling due to fluid accumulation", "Muscle pain", "Joint stiffness"]',
 'Swelling due to fluid accumulation', 30)

ON CONFLICT DO NOTHING;

COMMIT;
