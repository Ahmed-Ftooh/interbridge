import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token'

const AGORA_BASIC_AUTH = Deno.env.get('AGORA_BASIC_AUTH') || ''
const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID') || ''
const AGORA_APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE') || ''
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER') || ''

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
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method Not Allowed' }, 405)
    }

    if (!AGORA_BASIC_AUTH) {
      return jsonResponse({
        error: 'Missing Agora credentials',
        details: 'AGORA_BASIC_AUTH is not set as a function secret',
      }, 500)
    }

    if (!AGORA_APP_ID || !AGORA_APP_CERTIFICATE) {
      return jsonResponse({
        error: 'Missing Agora credentials',
        details: 'AGORA_APP_ID or AGORA_APP_CERTIFICATE not set as function secrets',
      }, 500)
    }

    if (!TWILIO_PHONE_NUMBER) {
      return jsonResponse({
        error: 'Missing Twilio phone number',
        details: 'TWILIO_PHONE_NUMBER is not set as a function secret',
      }, 500)
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse({
        error: 'Missing Supabase credentials',
        details: 'SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set',
      }, 500)
    }

    const authHeader = req.headers.get('authorization') || ''
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : ''
    if (!token) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json().catch(() => null)
    const channel = body?.channel
    const to = body?.to
    const action = body?.action ?? 'outbound'
    const callId = body?.call_id ?? body?.callId ?? body?.callid

    if (!channel) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channel: string, ... }',
      }, 400)
    }

    if (action === 'outbound' && !to) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channel: string, to: string }',
      }, 400)
    }

    if (action === 'hangup' && !callId) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channel: string, call_id: string }',
      }, 400)
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { data: userData, error: userError } = await supabase.auth.getUser(token)
    const user = userData?.user
    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const { data: requestRow, error: requestError } = await supabase
      .from('interpreter_requests')
      .select('requester_id, accepted_by, matched_interpreter_id')
      .eq('id', String(channel))
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

    let agoraPayload: Record<string, string> = {}

    if (action === 'hangup') {
      agoraPayload = {
        action: 'hangup',
        appid: AGORA_APP_ID,
        callid: String(callId),
        channel: String(channel),
      }
    } else {
      // --- THIS IS THE PART THAT WAS MISSING ---
      // Ensure the numbers always have a + sign for E.164 telecom standards
      const formattedTo = String(to).startsWith('+') ? String(to) : `+${to}`
      const formattedFrom = String(TWILIO_PHONE_NUMBER).startsWith('+')
        ? String(TWILIO_PHONE_NUMBER)
        : `+${TWILIO_PHONE_NUMBER}`

      const expirationTimeInSeconds = 3600
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds
      const agoraToken = RtcTokenBuilder.buildTokenWithUid(
        AGORA_APP_ID,
        AGORA_APP_CERTIFICATE,
        String(channel),
        0,
        RtcRole.PUBLISHER,
        privilegeExpiredTs,
      )

      // Build the payload using the formatted numbers
      agoraPayload = {
        action: 'outbound',
        appid: AGORA_APP_ID,
        uid: '0',
        channel: String(channel),
        region: 'AREA_CODE_NA',
        prompt: 'false',
        to: formattedTo,
        from: formattedFrom,
        sip: 'interbridge-app.pstn.ashburn.twilio.com',
        webhook_url: 'https://gwvxwaqicnwiplafayoh.supabase.co/functions/v1/twilio-webhook',
        token: agoraToken,
      }
    }

    const response = await fetch('https://sipcm.agora.io/v1/api/pstn', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': AGORA_BASIC_AUTH,
      },
      body: JSON.stringify(agoraPayload),
    })

    const contentType = response.headers.get('content-type') || ''
    const data = contentType.includes('application/json')
      ? await response.json().catch(() => ({}))
      : await response.text().catch(() => '')

    let resolvedCallId: string | null = null
    if (data && typeof data === 'object') {
      const record = data as Record<string, unknown>
      const nested = record['data'] as Record<string, unknown> | undefined
      resolvedCallId =
        (record['call_id'] as string | undefined) ||
        (record['callid'] as string | undefined) ||
        (record['callId'] as string | undefined) ||
        (record['id'] as string | undefined) ||
        (nested?.['call_id'] as string | undefined) ||
        (nested?.['callid'] as string | undefined) ||
        (nested?.['callId'] as string | undefined) ||
        null
    }

    const payload =
      data && typeof data === 'object'
        ? { ...(data as Record<string, unknown>), call_id: resolvedCallId }
        : { raw: data, call_id: resolvedCallId }

    return new Response(JSON.stringify(payload), {
      status: response.status,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (err) {
    return jsonResponse({ error: 'Unexpected error', details: String(err) }, 500)
  }
})