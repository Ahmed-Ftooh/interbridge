-- Migration: Create phone_calls table for Twilio call tracking
-- This table tracks all outbound phone calls made to patients

CREATE TABLE IF NOT EXISTS phone_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_sid TEXT UNIQUE NOT NULL, -- Twilio Call SID
  request_id UUID REFERENCES interpreter_requests(id) ON DELETE SET NULL,
  caller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Doctor/Interpreter who initiated
  to_phone TEXT NOT NULL, -- Patient phone number
  from_phone TEXT NOT NULL, -- Twilio phone number used
  status TEXT NOT NULL DEFAULT 'initiated', -- initiated, ringing, in-progress, completed, failed, busy, no-answer
  direction TEXT NOT NULL DEFAULT 'outbound',
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  answered_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_phone_calls_request_id ON phone_calls(request_id);
CREATE INDEX IF NOT EXISTS idx_phone_calls_caller_id ON phone_calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_phone_calls_status ON phone_calls(status);
CREATE INDEX IF NOT EXISTS idx_phone_calls_call_sid ON phone_calls(call_sid);

-- Enable RLS
ALTER TABLE phone_calls ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own calls
CREATE POLICY "Users can view their own calls"
  ON phone_calls FOR SELECT
  USING (caller_id = auth.uid());

-- Policy: Users can insert calls (via edge function with service role)
CREATE POLICY "Service role can manage calls"
  ON phone_calls FOR ALL
  USING (true)
  WITH CHECK (true);

-- Add comment
COMMENT ON TABLE phone_calls IS 'Tracks all Twilio phone calls made to patients';
