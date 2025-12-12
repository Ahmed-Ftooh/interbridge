-- Interbridge core schema expansion (quiz, badges, shifts, org wallet, invites)

-- Enums
DO $$ BEGIN
  CREATE TYPE quiz_type AS ENUM ('general','medical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE medical_section_type AS ENUM (
    'neurology','cardiology','respiratory','gastrointestinal','endocrinology',
    'renal','ob_gyn','oncology','emergency','psychology','musculoskeletal'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Organizations wallet ledger
CREATE TABLE IF NOT EXISTS public.organization_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (transaction_type IN ('topup','call_charge','refund')),
  amount numeric(12,2) NOT NULL,
  balance_after numeric(12,2) NOT NULL,
  call_id uuid REFERENCES public.call_logs(id),
  doctor_id uuid REFERENCES auth.users(id),
  payment_reference text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Maintain organizations.wallet_balance via ledger
CREATE OR REPLACE FUNCTION public.update_org_wallet_balance()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.organizations
    SET wallet_balance = NEW.balance_after,
        updated_at = now()
    WHERE id = NEW.organization_id;
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS trg_update_org_wallet_balance ON public.organization_transactions;
CREATE TRIGGER trg_update_org_wallet_balance
AFTER INSERT ON public.organization_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_org_wallet_balance();

-- Invites for doctors to join organizations
CREATE TABLE IF NOT EXISTS public.organization_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES auth.users(id),
  invite_code text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('doctor')),
  expires_at timestamptz NOT NULL,
  redeemed_by uuid REFERENCES auth.users(id),
  redeemed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Flexible shifts per interpreter (date-based)
CREATE TABLE IF NOT EXISTS public.interpreter_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shift_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, shift_date, start_time)
);

-- Quiz questions
CREATE TABLE IF NOT EXISTS public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_type quiz_type NOT NULL,
  medical_section medical_section_type,
  question_text text NOT NULL,
  option_a text NOT NULL,
  option_b text NOT NULL,
  option_c text NOT NULL,
  option_d text NOT NULL,
  correct_option char(1) NOT NULL CHECK (correct_option IN ('A','B','C','D')),
  difficulty int DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 3),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Quiz attempts
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quiz_type quiz_type NOT NULL,
  medical_section medical_section_type,
  total_questions int NOT NULL,
  correct_answers int NOT NULL,
  score_percentage numeric(5,2) NOT NULL,
  time_taken_seconds int,
  passed boolean NOT NULL,
  answers jsonb,
  taken_at timestamptz DEFAULT now()
);

-- Badges (80%+ per section)
CREATE TABLE IF NOT EXISTS public.interpreter_badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_type medical_section_type NOT NULL,
  score_percentage numeric(5,2) NOT NULL,
  earned_at timestamptz DEFAULT now(),
  UNIQUE(user_id, badge_type)
);

-- Award badge trigger
CREATE OR REPLACE FUNCTION public.award_badge_on_quiz_pass()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.quiz_type = 'medical' AND NEW.passed = true AND NEW.medical_section IS NOT NULL THEN
    INSERT INTO public.interpreter_badges(user_id, badge_type, score_percentage)
    VALUES (NEW.user_id, NEW.medical_section, NEW.score_percentage)
    ON CONFLICT (user_id, badge_type) DO UPDATE
      SET score_percentage = GREATEST(public.interpreter_badges.score_percentage, EXCLUDED.score_percentage),
          earned_at = now();
  END IF;
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS trg_award_badge_on_quiz_pass ON public.quiz_attempts;
CREATE TRIGGER trg_award_badge_on_quiz_pass
AFTER INSERT ON public.quiz_attempts
FOR EACH ROW EXECUTE FUNCTION public.award_badge_on_quiz_pass();

-- Minimal seed questions (placeholder)
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option)
VALUES
('general', NULL, 'Confidentiality means?', 'Share info', 'Keep info private', 'Speak fast', 'Use jargon', 'B')
ON CONFLICT DO NOTHING;

INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option)
VALUES
('medical','neurology','What is stroke?', 'MI', 'CVA', 'PE', 'TIA', 'B'),
('medical','cardiology','ECG stands for?', 'Electrocardiogram','Electronic Cardio Gauge','Emergency Cardio','External Generator','A'),
('medical','respiratory','Primary gas for respiration?', 'CO2','O2','N2','CO','B'),
('medical','gastrointestinal','GERD primarily affects?', 'Heart','Stomach','Liver','Kidney','B'),
('medical','endocrinology','Insulin produced by?', 'Liver','Pancreas','Kidney','Intestine','B'),
('medical','renal','Main function of kidneys?', 'Hormones','Filtration','Digestion','Respiration','B'),
('medical','ob_gyn','OB refers to?', 'Orthopedic','Obstetrics','Oncology','Optometry','B'),
('medical','oncology','Malignant means?', 'Benign','Cancerous','Non-cancer','Inflamed','B'),
('medical','emergency','CPR stands for?', 'Cardio Pulse','Cardiopulmonary Resuscitation','Critical Patient Response','Chest Pressure Rhythm','B'),
('medical','psychology','PTSD stands for?', 'Post Treatment Stress Disease','Post Traumatic Stress Disorder','Primary Trauma Stress Dysfunction','Psych Trauma Syndrome','B'),
('medical','musculoskeletal','Fracture refers to?', 'Sprain','Bone break','Dislocation','Bruise','B')
ON CONFLICT DO NOTHING;

-- RLS enable
ALTER TABLE public.organization_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interpreter_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interpreter_badges ENABLE ROW LEVEL SECURITY;

-- RLS policies (basic)
-- Org transactions: org admins can manage, doctors/org members can view
DROP POLICY IF EXISTS org_tx_admin_manage ON public.organization_transactions;
CREATE POLICY org_tx_admin_manage ON public.organization_transactions
  FOR ALL USING (
    EXISTS(SELECT 1 FROM public.organizations o JOIN public.organization_members m ON m.organization_id = o.id
           WHERE o.id = organization_id AND m.user_id = auth.uid() AND m.role = 'organization_admin')
  );
DROP POLICY IF EXISTS org_tx_member_view ON public.organization_transactions;
CREATE POLICY org_tx_member_view ON public.organization_transactions
  FOR SELECT USING (
    EXISTS(SELECT 1 FROM public.organizations o JOIN public.organization_members m ON m.organization_id = o.id
           WHERE o.id = organization_id AND m.user_id = auth.uid())
  );

-- Invites: admin manage; redeem via secured function
DROP POLICY IF EXISTS org_inv_admin_manage ON public.organization_invites;
CREATE POLICY org_inv_admin_manage ON public.organization_invites
  FOR ALL USING (
    EXISTS(SELECT 1 FROM public.organizations o JOIN public.organization_members m ON m.organization_id = o.id
           WHERE o.id = organization_id AND m.user_id = auth.uid() AND m.role = 'organization_admin')
  );

-- Shifts: interpreter manages own rows; admin can view all
DROP POLICY IF EXISTS shifts_self_manage ON public.interpreter_shifts;
CREATE POLICY shifts_self_manage ON public.interpreter_shifts
  FOR ALL USING (user_id = auth.uid());
DROP POLICY IF EXISTS shifts_admin_view ON public.interpreter_shifts;
CREATE POLICY shifts_admin_view ON public.interpreter_shifts
  FOR SELECT USING (
    EXISTS(SELECT 1 FROM public.users_profile up WHERE up.user_id = auth.uid() AND up.role IN ('admin','superadmin'))
  );

-- Quiz: everyone can read questions; users can see own attempts; admin sees all
DROP POLICY IF EXISTS quiz_questions_read ON public.quiz_questions;
CREATE POLICY quiz_questions_read ON public.quiz_questions FOR SELECT USING (true);
DROP POLICY IF EXISTS quiz_attempts_self ON public.quiz_attempts;
CREATE POLICY quiz_attempts_self ON public.quiz_attempts FOR ALL USING (user_id = auth.uid());
DROP POLICY IF EXISTS quiz_attempts_admin ON public.quiz_attempts;
CREATE POLICY quiz_attempts_admin ON public.quiz_attempts FOR SELECT USING (
  EXISTS(SELECT 1 FROM public.users_profile up WHERE up.user_id = auth.uid() AND up.role IN ('admin','superadmin'))
);

-- Badges: self-view; admin-view
DROP POLICY IF EXISTS badges_self_view ON public.interpreter_badges;
CREATE POLICY badges_self_view ON public.interpreter_badges FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS badges_admin_view ON public.interpreter_badges;
CREATE POLICY badges_admin_view ON public.interpreter_badges FOR SELECT USING (
  EXISTS(SELECT 1 FROM public.users_profile up WHERE up.user_id = auth.uid() AND up.role IN ('admin','superadmin'))
);
