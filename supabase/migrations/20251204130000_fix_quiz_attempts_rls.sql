-- Simplify RLS policies for quiz_attempts and interpreter_badges

-- Drop existing policies
DROP POLICY IF EXISTS quiz_attempts_access ON public.quiz_attempts;
DROP POLICY IF EXISTS quiz_attempts_select ON public.quiz_attempts;
DROP POLICY IF EXISTS quiz_attempts_insert ON public.quiz_attempts;
DROP POLICY IF EXISTS quiz_attempts_update ON public.quiz_attempts;
DROP POLICY IF EXISTS quiz_attempts_delete ON public.quiz_attempts;

DROP POLICY IF EXISTS interpreter_badges_select ON public.interpreter_badges;
DROP POLICY IF EXISTS interpreter_badges_insert ON public.interpreter_badges;
DROP POLICY IF EXISTS interpreter_badges_update ON public.interpreter_badges;
DROP POLICY IF EXISTS interpreter_badges_delete ON public.interpreter_badges;

-- Create simplified policies for quiz_attempts
CREATE POLICY quiz_attempts_select ON public.quiz_attempts
  FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY quiz_attempts_insert ON public.quiz_attempts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY quiz_attempts_update ON public.quiz_attempts
  FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY quiz_attempts_delete ON public.quiz_attempts
  FOR DELETE USING (is_admin());

-- Create simplified policies for interpreter_badges
CREATE POLICY interpreter_badges_select ON public.interpreter_badges
  FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY interpreter_badges_insert ON public.interpreter_badges
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY interpreter_badges_update ON public.interpreter_badges
  FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY interpreter_badges_delete ON public.interpreter_badges
  FOR DELETE USING (is_admin());
