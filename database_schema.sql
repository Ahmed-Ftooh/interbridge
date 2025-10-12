-- Call Sessions Table Schema
-- This table stores call duration and session information

CREATE TABLE IF NOT EXISTS call_sessions (
  id SERIAL PRIMARY KEY,
  channel_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ended_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional useful fields for analytics
  call_type TEXT DEFAULT 'voice', -- 'voice', 'video', etc.
  connection_quality TEXT, -- 'excellent', 'good', 'poor', 'failed'
  end_reason TEXT, -- 'user_hangup', 'connection_lost', 'error', etc.
  remote_user_id UUID, -- ID of the other participant
  
  -- Constraints
  CONSTRAINT valid_duration CHECK (duration_seconds >= 0),
  CONSTRAINT valid_timestamps CHECK (ended_at >= started_at),
  CONSTRAINT valid_call_type CHECK (call_type IN ('voice', 'video')),
  CONSTRAINT valid_quality CHECK (connection_quality IN ('excellent', 'good', 'poor', 'failed')),
  CONSTRAINT valid_end_reason CHECK (end_reason IN ('user_hangup', 'connection_lost', 'error', 'timeout', 'other'))
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_call_sessions_user_id ON call_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_channel_id ON call_sessions(channel_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_created_at ON call_sessions(created_at);
CREATE INDEX IF NOT EXISTS idx_call_sessions_started_at ON call_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_call_sessions_remote_user_id ON call_sessions(remote_user_id);

-- Optional: Add RLS (Row Level Security) policies
ALTER TABLE call_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own call sessions
CREATE POLICY "Users can view own call sessions" ON call_sessions
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own call sessions
CREATE POLICY "Users can insert own call sessions" ON call_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Optional: Add a view for call statistics
CREATE OR REPLACE VIEW call_statistics AS
SELECT 
  user_id,
  COUNT(*) as total_calls,
  SUM(duration_seconds) as total_duration_seconds,
  AVG(duration_seconds) as average_duration_seconds,
  MIN(started_at) as first_call,
  MAX(ended_at) as last_call
FROM call_sessions
GROUP BY user_id;

-- Call Feedback Table Schema
-- This table stores user feedback after calls

CREATE TABLE IF NOT EXISTS call_feedback (
  id SERIAL PRIMARY KEY,
  channel_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  connection_quality TEXT NOT NULL CHECK (connection_quality IN ('excellent', 'good', 'poor', 'failed')),
  call_experience TEXT NOT NULL CHECK (call_experience IN ('very_satisfied', 'satisfied', 'neutral', 'dissatisfied', 'very_dissatisfied')),
  comments TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_rating CHECK (rating >= 1 AND rating <= 5)
);

-- Indexes for call feedback
CREATE INDEX IF NOT EXISTS idx_call_feedback_user_id ON call_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_call_feedback_channel_id ON call_feedback(channel_id);
CREATE INDEX IF NOT EXISTS idx_call_feedback_created_at ON call_feedback(created_at);

-- Enable RLS for call feedback
ALTER TABLE call_feedback ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own feedback
CREATE POLICY "Users can view own call feedback" ON call_feedback
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own feedback
CREATE POLICY "Users can insert own call feedback" ON call_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own feedback (within 24 hours)
CREATE POLICY "Users can update own call feedback" ON call_feedback
  FOR UPDATE USING (auth.uid() = user_id AND created_at > NOW() - INTERVAL '24 hours');

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON call_sessions TO authenticated;
GRANT SELECT ON call_statistics TO authenticated;
GRANT SELECT, INSERT, UPDATE ON call_feedback TO authenticated;
