-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE,
    type TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_timestamp ON public.notifications(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to see only their own notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Create policy to allow users to insert their own notifications
CREATE POLICY "Users can insert their own notifications" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policy to allow users to update their own notifications
CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Create policy to allow users to delete their own notifications
CREATE POLICY "Users can delete their own notifications" ON public.notifications
    FOR DELETE USING (auth.uid() = user_id); 