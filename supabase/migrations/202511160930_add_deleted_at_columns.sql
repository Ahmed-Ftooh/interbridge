-- Migration: add deleted_at columns for soft deletion strategy
-- Date: 2025-11-16
-- Description: Introduces nullable deleted_at timestamp columns and supporting partial indexes
-- for tables participating in user data removal flows.

-- Safety: Use IF NOT EXISTS for columns so migration is idempotent if re-run.
-- Indexes: Partial indexes where deleted_at IS NULL to keep active-row queries fast.

-- USER PROFILES (table name in code: users_profile)
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS users_profile_active_idx ON public.users_profile (user_id)
  WHERE deleted_at IS NULL;

-- INTERPRETER REQUESTS
ALTER TABLE public.interpreter_requests
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS interpreter_requests_active_idx ON public.interpreter_requests (requester_id, interpreter_id)
  WHERE deleted_at IS NULL;

-- DOCUMENT TRANSLATION REQUESTS
ALTER TABLE public.document_translation_requests
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS document_translation_requests_active_idx ON public.document_translation_requests (requester_id)
  WHERE deleted_at IS NULL;

-- CHAT MESSAGES
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS chat_messages_active_idx ON public.chat_messages (sender_id, created_at)
  WHERE deleted_at IS NULL;

-- OPTIONAL: Row Level Security policy adjustments (uncomment & tailor if RLS enabled)
-- NOTE: Ensure existing select/update policies reference deleted_at IS NULL as needed.
-- Example:
-- ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY messages_select_active ON public.messages
--   FOR SELECT USING (deleted_at IS NULL);
-- CREATE POLICY messages_insert ON public.messages FOR INSERT WITH CHECK (true);
-- CREATE POLICY messages_update_active ON public.messages FOR UPDATE USING (deleted_at IS NULL) WITH CHECK (deleted_at IS NULL);
-- CREATE POLICY messages_delete_soft ON public.messages FOR UPDATE USING (auth.uid() = sender_id) WITH CHECK (auth.uid() = sender_id);

-- ALTER TABLE public.users_profile DROP COLUMN deleted_at;
-- ALTER TABLE public.interpreter_requests DROP COLUMN deleted_at;
-- ALTER TABLE public.document_translation_requests DROP COLUMN deleted_at;
-- ALTER TABLE public.chat_messages DROP COLUMN deleted_at;

-- End of migration
