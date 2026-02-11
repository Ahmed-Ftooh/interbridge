-- Create OneSignal player IDs table for push notifications (replacing FCM tokens)
CREATE TABLE IF NOT EXISTS public.onesignal_player_ids (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    player_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, player_id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_onesignal_player_ids_user_id ON public.onesignal_player_ids(user_id);
CREATE INDEX IF NOT EXISTS idx_onesignal_player_ids_player_id ON public.onesignal_player_ids(player_id);

-- Enable Row Level Security
ALTER TABLE public.onesignal_player_ids ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own player IDs
CREATE POLICY "Users can manage their own player IDs" ON public.onesignal_player_ids
    FOR ALL USING (auth.uid() = user_id);

-- Create trigger to automatically update updated_at (reuse existing function)
CREATE TRIGGER update_onesignal_player_ids_updated_at 
    BEFORE UPDATE ON public.onesignal_player_ids 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Grant service role full access (needed for edge functions)
GRANT ALL ON public.onesignal_player_ids TO service_role;
