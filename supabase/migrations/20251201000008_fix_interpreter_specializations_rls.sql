-- Fix RLS policy for interpreter_specializations table to allow DELETE operations

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can manage own specializations" ON interpreter_specializations;

-- Create new policy that allows INSERT, UPDATE, DELETE for authenticated users on their own data
CREATE POLICY "Users can manage own specializations"
  ON interpreter_specializations
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Ensure RLS is enabled
ALTER TABLE interpreter_specializations ENABLE ROW LEVEL SECURITY;
