-- Create document translation requests table
CREATE TABLE IF NOT EXISTS public.document_translation_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_language TEXT NOT NULL,
    to_language TEXT NOT NULL,
    specialization TEXT,
    text TEXT,
    title TEXT,
    comment TEXT,
    translation_method TEXT,
    file_url TEXT,
    file_type TEXT,
    file_name TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    accepted_by UUID REFERENCES auth.users(id),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    translated_text TEXT,
    translated_file_url TEXT
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_document_translation_requests_requester_id ON public.document_translation_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_document_translation_requests_status ON public.document_translation_requests(status);
CREATE INDEX IF NOT EXISTS idx_document_translation_requests_created_at ON public.document_translation_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_document_translation_requests_accepted_by ON public.document_translation_requests(accepted_by);

-- Enable Row Level Security
ALTER TABLE public.document_translation_requests ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own requests
CREATE POLICY "Users can manage their own document translation requests" ON public.document_translation_requests
    FOR ALL USING (auth.uid() = requester_id);

-- Create policy to allow interpreters to view pending requests
CREATE POLICY "Interpreters can view pending document translation requests" ON public.document_translation_requests
    FOR SELECT USING (status = 'pending');

-- Create policy to allow interpreters to update requests they accept
CREATE POLICY "Interpreters can update document translation requests they accept" ON public.document_translation_requests
    FOR UPDATE USING (auth.uid() = accepted_by);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_translation_requests TO authenticated;

