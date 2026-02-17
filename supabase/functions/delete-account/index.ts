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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request): Promise<Response> => {
  try {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }

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
    
    // Delete organization-related records first
    // Get organizations where user is admin to potentially delete them
    const { data: adminOrgs } = await adminClient
      .from('organization_members')
      .select('organization_id')
      .eq('user_id', targetUserId)
      .eq('role', 'organization_admin');

    // Delete organization invites created by this user
    await adminClient.from('organization_invites').delete().eq('inviter_id', targetUserId);
    
    // Clear redeemed_by references (set to null instead of delete)
    await adminClient.from('organization_invites').update({ redeemed_by: null }).eq('redeemed_by', targetUserId);
    
    // Delete organization transactions for this doctor
    await adminClient.from('organization_transactions').delete().eq('doctor_id', targetUserId);
    
    // Delete organization membership
    await adminClient.from('organization_members').delete().eq('user_id', targetUserId);
    
    // If user was the only admin, delete the organization and all its data
    if (adminOrgs && adminOrgs.length > 0) {
      for (const org of adminOrgs) {
        // Check if there are other admins
        const { data: otherAdmins } = await adminClient
          .from('organization_members')
          .select('id')
          .eq('organization_id', org.organization_id)
          .eq('role', 'organization_admin')
          .neq('user_id', targetUserId);
        
        // If no other admins, delete the organization
        if (!otherAdmins || otherAdmins.length === 0) {
          // Delete all organization-related data
          await adminClient.from('organization_invites').delete().eq('organization_id', org.organization_id);
          await adminClient.from('organization_transactions').delete().eq('organization_id', org.organization_id);
          await adminClient.from('organization_members').delete().eq('organization_id', org.organization_id);
          // Update call_logs to remove organization reference
          await adminClient.from('call_logs').update({ organization_id: null }).eq('organization_id', org.organization_id);
          await adminClient.from('call_requests').update({ organization_id: null }).eq('organization_id', org.organization_id);
          // Delete the organization
          await adminClient.from('organizations').delete().eq('id', org.organization_id);
        }
      }
    }

    // Delete call-related records
    await adminClient.from('call_declines').delete().eq('interpreter_id', targetUserId);
    await adminClient.from('call_feedback').delete().eq('user_id', targetUserId);
    await adminClient.from('call_sessions').delete().eq('user_id', targetUserId);
    
    // Update call_requests to remove user references (set to null)
    await adminClient.from('call_requests').update({ caller_id: null }).eq('caller_id', targetUserId);
    await adminClient.from('call_requests').update({ interpreter_id: null }).eq('interpreter_id', targetUserId);
    
    // Update call_logs to remove user references
    await adminClient.from('call_logs').update({ requester_id: null }).eq('requester_id', targetUserId);
    await adminClient.from('call_logs').update({ interpreter_id: null }).eq('interpreter_id', targetUserId);
    await adminClient.from('call_logs').update({ admin_listener_id: null }).eq('admin_listener_id', targetUserId);

    // Delete interpreter-related records
    await adminClient.from('interpreter_badges').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_flexible_shifts').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_shifts').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_certificates').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_language_skills').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_languages').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_skills').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_specializations').delete().eq('user_id', targetUserId);
    
    // Delete interpreter applications (need to clear last_application_id first)
    await adminClient.from('users_profile').update({ last_application_id: null }).eq('user_id', targetUserId);
    await adminClient.from('interpreter_applications').delete().eq('user_id', targetUserId);
    await adminClient.from('interpreter_applications').update({ reviewer_id: null }).eq('reviewer_id', targetUserId);
    
    // Delete interpreter details
    await adminClient.from('interpreter_details').delete().eq('user_id', targetUserId);
    
    // Delete quiz attempts
    await adminClient.from('quiz_attempts').delete().eq('user_id', targetUserId);
    
    // Delete admin messages
    await adminClient.from('admin_interpreter_messages').delete().eq('interpreter_id', targetUserId);
    await adminClient.from('admin_interpreter_messages').delete().eq('admin_id', targetUserId);

    // Delete notifications and OneSignal player IDs (and legacy FCM tokens if any)
    await adminClient.from('notifications').delete().eq('user_id', targetUserId);
    await adminClient.from('onesignal_player_ids').delete().eq('user_id', targetUserId);
    await adminClient.from('fcm_tokens').delete().eq('user_id', targetUserId); // Legacy cleanup

    // Delete original tables from the function
    await adminClient.from('chat_messages').delete().eq('sender_id', targetUserId);
    await adminClient.from('document_translation_requests').delete().eq('requester_id', targetUserId);
    await adminClient.from('document_translation_requests').update({ accepted_by: null }).eq('accepted_by', targetUserId);
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
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function adminAnonValue(field: string): string {
  return `${field}_deleted_${Date.now()}`;
}
