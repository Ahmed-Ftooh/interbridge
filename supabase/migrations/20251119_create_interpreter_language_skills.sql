-- Creates interpreter_language_skills table to map skills per working language
CREATE TABLE IF NOT EXISTS interpreter_language_skills (
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  language_id integer NOT NULL REFERENCES languages (id) ON DELETE CASCADE,
  skill_id integer NOT NULL REFERENCES skills (id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, language_id, skill_id)
);

-- Basic RLS policy placeholders (adjust in Supabase dashboard as needed)
ALTER TABLE interpreter_language_skills ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to manage their own mappings
DROP POLICY IF EXISTS "Users manage own language skills" ON interpreter_language_skills;
CREATE POLICY "Users manage own language skills"
  ON interpreter_language_skills
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);