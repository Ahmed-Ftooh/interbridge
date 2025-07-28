-- Fix RLS policy for users_profile table
-- Run these commands in your Supabase SQL editor

-- First, check if RLS is enabled on the table
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'users_profile';

-- Option 1: Disable RLS entirely for users_profile table (simplest solution)
ALTER TABLE users_profile DISABLE ROW LEVEL SECURITY;

-- Option 2: If you want to keep RLS enabled, create proper policies
-- Drop existing policies if any
-- DROP POLICY IF EXISTS "Users can insert their own profile" ON users_profile;
-- DROP POLICY IF EXISTS "Users can view their own profile" ON users_profile;
-- DROP POLICY IF EXISTS "Users can update their own profile" ON users_profile;

-- Create policies for users_profile table
-- CREATE POLICY "Users can insert their own profile" ON users_profile
--     FOR INSERT WITH CHECK (auth.uid() = user_id);

-- CREATE POLICY "Users can view their own profile" ON users_profile
--     FOR SELECT USING (auth.uid() = user_id);

-- CREATE POLICY "Users can update their own profile" ON users_profile
--     FOR UPDATE USING (auth.uid() = user_id);

-- Option 3: Allow all operations for authenticated users
-- CREATE POLICY "Authenticated users can manage profiles" ON users_profile
--     FOR ALL USING (auth.role() = 'authenticated'); 