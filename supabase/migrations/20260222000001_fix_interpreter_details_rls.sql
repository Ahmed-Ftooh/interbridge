-- Fix RLS policies for interpreter_details table
-- The table has RLS enabled but no policies allowing authenticated users
-- to insert/update their own rows, causing:
--   "new row violates row-level security policy (USING expression)"
-- during registration finalization.

ALTER TABLE public.interpreter_details ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to start fresh
DROP POLICY IF EXISTS "Users can view own interpreter details" ON public.interpreter_details;
DROP POLICY IF EXISTS "Users can insert own interpreter details" ON public.interpreter_details;
DROP POLICY IF EXISTS "Users can update own interpreter details" ON public.interpreter_details;
DROP POLICY IF EXISTS "Users can delete own interpreter details" ON public.interpreter_details;
DROP POLICY IF EXISTS "interpreter_details_select" ON public.interpreter_details;
DROP POLICY IF EXISTS "interpreter_details_insert" ON public.interpreter_details;
DROP POLICY IF EXISTS "interpreter_details_update" ON public.interpreter_details;
DROP POLICY IF EXISTS "interpreter_details_delete" ON public.interpreter_details;

-- SELECT: users can read their own details; admins can read all
CREATE POLICY interpreter_details_select ON public.interpreter_details
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: users can insert their own row
CREATE POLICY interpreter_details_insert ON public.interpreter_details
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: users can update their own row
CREATE POLICY interpreter_details_update ON public.interpreter_details
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: users can delete their own row
CREATE POLICY interpreter_details_delete ON public.interpreter_details
  FOR DELETE USING (auth.uid() = user_id);
