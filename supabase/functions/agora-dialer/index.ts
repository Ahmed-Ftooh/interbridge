import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const AGORA_BASIC_AUTH = Deno.env.get('AGORA_BASIC_AUTH') || ''

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

    const body = await req.json().catch(() => null)
    const channel = body?.channel
    const to = body?.to
    const from = body?.from

    if (!channel || !to || !from) {
      return jsonResponse({
        error: 'Invalid request body',
        details: 'Expected JSON with { channel: string, to: string, from: string }',
      }, 400)
    }

    // --- THIS IS THE PART THAT WAS MISSING ---
    // Ensure the numbers always have a + sign for E.164 telecom standards
    const formattedTo = String(to).startsWith('+') ? String(to) : `+${to}`
    const formattedFrom = String(from).startsWith('+') ? String(from) : `+${from}`

    // Build the payload using the formatted numbers
  const agoraPayload: any = {
      action: 'outbound',
      appid: 'd561821cc6244180a0d44e1f2eb7de84',
      uid: "0",         // <--- ADD THIS EXACT LINE BACK IN
      channel: String(channel),
      region: 'AREA_CODE_NA',
      prompt: 'false', 
      to: formattedTo,
      from: formattedFrom,
      sip: 'interbridge-app.pstn.ashburn.twilio.com',
      webhook_url: 'https://gwvxwaqicnwiplafayoh.supabase.co/functions/v1/twilio-webhook',
    }

    // Add the universal token your Flutter app just generated
    if (body?.token) {
      agoraPayload.token = String(body.token)
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

    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (err) {
    return jsonResponse({ error: 'Unexpected error', details: String(err) }, 500)
  }
})