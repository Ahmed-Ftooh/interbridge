-- Create FCM tokens table for push notifications
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token);

-- Enable Row Level Security
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own FCM tokens
CREATE POLICY "Users can manage their own FCM tokens" ON public.fcm_tokens
    FOR ALL USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_fcm_tokens_updated_at 
    BEFORE UPDATE ON public.fcm_tokens 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column(); 