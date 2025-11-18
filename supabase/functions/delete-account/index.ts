// Supabase Edge Function: delete-account
// Endpoint: /functions/v1/delete-account
// Mode: hard (default) or soft deletion via request body { mode: 'soft' }
// IMPORTANT: To enable user deletion, set the environment variable SUPABASE_SERVICE_ROLE_KEY
// and SUPABASE_URL for this function. Never expose the service role key to the client.
// The client invokes this with its own user JWT; we validate the caller matches the target user_id.
// Soft delete strategy: mark user-related records with deleted_at and anonymize PII.
// Hard delete strategy: remove rows then delete auth user.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

interface DeleteRequestBody {
  user_id?: string;
  mode?: 'soft' | 'hard';
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

const adminClient = createClient(SUPABASE_URL!, SERVICE_ROLE_KEY!, {
  auth: { autoRefreshToken: false, persistSession: false },
});

serve(async (req: Request): Promise<Response> => {
  try {
    if (req.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }
    const jwt = authHeader.replace('Bearer ', '').trim();

    // Verify caller identity
    const { data: userData, error: userErr } = await adminClient.auth.getUser(jwt);
    if (userErr || !userData.user) {
      return json({ error: 'Invalid or expired token' }, 401);
    }

    const body: DeleteRequestBody = await req.json();
    const targetUserId = body.user_id?.trim();
    if (!targetUserId) {
      return json({ error: 'Missing user_id' }, 400);
    }

    if (targetUserId !== userData.user.id) {
      return json({ error: 'Forbidden: cannot delete another user' }, 403);
    }

    const mode = body.mode === 'soft' ? 'soft' : 'hard';

    // TABLE NAMES (adjusted to actual schema in app code)
    // tables: users_profile, interpreter_requests, document_translation_requests, chat_messages
    // SOFT DELETE: set deleted_at timestamp & anonymize username / email in profiles
    if (mode === 'soft') {
      const deletedAt = new Date().toISOString();

      await adminClient.from('users_profile').update({
        deleted_at: deletedAt,
        username: adminAnonValue('username'),
        display_name: adminAnonValue('display_name'),
      }).eq('user_id', targetUserId);

      await adminClient.from('interpreter_requests').update({ deleted_at: deletedAt }).eq('requester_id', targetUserId);
      await adminClient.from('interpreter_requests').update({ deleted_at: deletedAt }).eq('interpreter_id', targetUserId);

      await adminClient.from('document_translation_requests').update({ deleted_at: deletedAt }).eq('requester_id', targetUserId);

      await adminClient.from('chat_messages').update({ deleted_at: deletedAt }).eq('sender_id', targetUserId);

      // Do NOT delete auth user in soft mode; user cannot log back in after anonymization? optional.
      // Instead, revoke tokens by setting banned_until.
      await adminClient.auth.admin.updateUserById(targetUserId, { bannedUntil: deletedAt });

      return json({ status: 'ok', mode });
    }

    // HARD DELETE FLOW
    // 1. Delete child records first to satisfy FK constraints
    await adminClient.from('chat_messages').delete().eq('sender_id', targetUserId);
    await adminClient.from('document_translation_requests').delete().eq('requester_id', targetUserId);
    await adminClient.from('interpreter_requests').delete().or(`requester_id.eq.${targetUserId},interpreter_id.eq.${targetUserId}`);
    await adminClient.from('users_profile').delete().eq('user_id', targetUserId);

    // 2. Delete auth user
    const { error: delErr } = await adminClient.auth.admin.deleteUser(targetUserId);
    if (delErr) {
      return json({ error: 'Auth deletion failed', details: delErr.message }, 500);
    }

    return json({ status: 'ok', mode });
  } catch (e) {
    console.error('Deletion error', e);
    return json({ error: 'Unhandled error', details: String(e) }, 500);
  }
});

function json(obj: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function adminAnonValue(field: string): string {
  return `${field}_deleted_${Date.now()}`;
}
