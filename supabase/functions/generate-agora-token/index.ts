import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token'

const APP_ID = Deno.env.get('AGORA_APP_ID') || ''
const APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE') || ''

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

    // Parse and validate body
    const body = await req.json().catch(() => null)
    const channelName = body?.channelName
    const uidRaw = body?.uid

    if (!channelName || (!uidRaw && uidRaw !== 0)) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channelName: string, uid: number|string }',
      }, 400)
    }

    const uid = typeof uidRaw === 'number' ? uidRaw : parseInt(String(uidRaw), 10)
    if (!Number.isFinite(uid) || uid < 0) {
      return jsonResponse({ error: 'Invalid uid value' }, 400)
    }

    // Token params
    const expirationTimeInSeconds = 3600
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

    // Build token
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      String(channelName),
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
    )

    return jsonResponse({ token })
  } catch (err) {
    return jsonResponse({ error: 'Unexpected error', details: String(err) }, 500)
  }
})
