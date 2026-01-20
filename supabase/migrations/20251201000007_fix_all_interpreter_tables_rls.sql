-- Fix RLS policies for all interpreter-related tables to allow full CRUD operations

-- interpreter_languages table
DROP POLICY IF EXISTS "Users can manage own languages" ON interpreter_languages;
CREATE POLICY "Users can manage own languages"
  ON interpreter_languages
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE interpreter_languages ENABLE ROW LEVEL SECURITY;

-- interpreter_specializations table
DROP POLICY IF EXISTS "Users can manage own specializations" ON interpreter_specializations;
CREATE POLICY "Users can manage own specializations"
  ON interpreter_specializations
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE interpreter_specializations ENABLE ROW LEVEL SECURITY;

-- interpreter_skills table
DROP POLICY IF EXISTS "Users can manage own skills" ON interpreter_skills;
CREATE POLICY "Users can manage own skills"
  ON interpreter_skills
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE interpreter_skills ENABLE ROW LEVEL SECURITY;

-- interpreter_language_skills table (the new per-language skills table)
DROP POLICY IF EXISTS "Users manage own language skills" ON interpreter_language_skills;
CREATE POLICY "Users manage own language skills"
  ON interpreter_language_skills
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE interpreter_language_skills ENABLE ROW LEVEL SECURITY;
