-- Add is_suspended column to interpreter_details table
-- This allows admins to suspend/activate interpreter accounts

ALTER TABLE interpreter_details 
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;

-- Add comment
COMMENT ON COLUMN interpreter_details.is_suspended IS 'Whether the interpreter account is suspended by admin';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_interpreter_details_suspended 
ON interpreter_details(is_suspended);
