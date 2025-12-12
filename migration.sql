-- Add is_online column to interpreter_details table
ALTER TABLE interpreter_details 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- Optional: Create a policy to allow interpreters to update their own online status if RLS is enabled
-- CREATE POLICY "Interpreters can update their own online status" 
-- ON interpreter_details FOR UPDATE 
-- USING (auth.uid() = user_id) 
-- WITH CHECK (auth.uid() = user_id);
