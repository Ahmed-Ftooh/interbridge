-- Create interpreter requests table
CREATE TABLE IF NOT EXISTS public.interpreter_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_language TEXT NOT NULL,
    to_language TEXT NOT NULL,
    specialization TEXT,
    urgency TEXT NOT NULL DEFAULT 'Normal',
    status TEXT NOT NULL DEFAULT 'pending',
    description TEXT,
    accepted_by UUID REFERENCES auth.users(id),
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_interpreter_requests_requester_id ON public.interpreter_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_interpreter_requests_status ON public.interpreter_requests(status);
CREATE INDEX IF NOT EXISTS idx_interpreter_requests_created_at ON public.interpreter_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.interpreter_requests ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own requests
CREATE POLICY "Users can manage their own requests" ON public.interpreter_requests
    FOR ALL USING (auth.uid() = requester_id);

-- Create policy to allow interpreters to view pending requests
CREATE POLICY "Interpreters can view pending requests" ON public.interpreter_requests
    FOR SELECT USING (status = 'pending');

-- Create policy to allow interpreters to update requests they accept
CREATE POLICY "Interpreters can update requests they accept" ON public.interpreter_requests
    FOR UPDATE USING (auth.uid() = accepted_by);

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_interpreter_requests_updated_at 
    BEFORE UPDATE ON public.interpreter_requests 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column(); 