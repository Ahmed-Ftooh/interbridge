import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token'

const APP_ID = Deno.env.get('AGORA_APP_ID') || ''
const APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE') || ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}

serve(async (req) => {
  try {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    // Only allow POST
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method Not Allowed' }, 405)
    }

    // Validate secrets
    if (!APP_ID || !APP_CERTIFICATE) {
      return jsonResponse({
        error: 'Missing Agora credentials',
        details: 'AGORA_APP_ID or AGORA_APP_CERTIFICATE not set as function secrets',
      }, 500)
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse({
        error: 'Missing Supabase credentials',
        details: 'SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set',
      }, 500)
    }

    const authHeader = req.headers.get('authorization') || ''
    const 
    authToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : ''
    if (!authToken) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    // Parse and validate body
    const body = await req.json().catch(() => null)
    const channelName = body?.channelName
    const uidRaw = body?.uid
    const roleRaw = body?.role // optional: 'publisher' (default) or 'subscriber'

    if (!channelName || (!uidRaw && uidRaw !== 0)) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channelName: string, uid: number|string, role?: "publisher"|"subscriber" }',
      }, 400)
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { data: userData, error: userError } = await supabase.auth.getUser(authToken)
    const user = userData?.user
    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const { data: requestRow, error: requestError } = await supabase
      .from('interpreter_requests')
      .select('requester_id, accepted_by, matched_interpreter_id')
      .eq('id', String(channelName))
      .maybeSingle()

    if (requestError) {
      return jsonResponse({ error: 'Request lookup failed' }, 500)
    }

    if (!requestRow) {
      return jsonResponse({ error: 'Request not found' }, 404)
    }

    const isParticipant =
      user.id === requestRow.requester_id ||
      user.id === requestRow.accepted_by ||
      user.id === requestRow.matched_interpreter_id

    if (!isParticipant) {
      return jsonResponse({ error: 'Forbidden' }, 403)
    }

    const uid = typeof uidRaw === 'number' ? uidRaw : parseInt(String(uidRaw), 10)
    if (!Number.isFinite(uid) || uid < 0) {
      return jsonResponse({ error: 'Invalid uid value' }, 400)
    }

    // Token params
    const expirationTimeInSeconds = 3600
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

    // Determine role: publisher (default) or subscriber (audience/listen-only)
    const agoraRole = roleRaw === 'subscriber' ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER

    // Build token
    const agoraToken = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      String(channelName),
      uid,
      agoraRole,
      privilegeExpiredTs,
    )

    return jsonResponse({ token: agoraToken })
  } catch (err) {
    return jsonResponse({ error: 'Unexpected error', details: String(err) }, 500)
  }
})
