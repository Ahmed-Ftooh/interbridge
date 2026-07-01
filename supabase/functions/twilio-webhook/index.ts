import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') || ''
const TWILIO_WEBHOOK_URL = Deno.env.get('TWILIO_WEBHOOK_URL') || ''

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false
  }
  let result = 0
  for (let i = 0; i < a.length; i += 1) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return result === 0
}

function buildTwilioSignaturePayload(
  url: string,
  bodyText: string,
  contentType: string,
): string {
  if (contentType.includes('application/json')) {
    return url + bodyText
  }

  const params = new URLSearchParams(bodyText)
  const entries = Array.from(params.entries()).sort(([a], [b]) => a.localeCompare(b))
  let payload = url
  for (const [key, value] of entries) {
    payload += key + value
  }
  return payload
}

async function computeTwilioSignature(
  url: string,
  bodyText: string,
  contentType: string,
  authToken: string,
): Promise<string> {
  const payload = buildTwilioSignaturePayload(url, bodyText, contentType)
  const key = new TextEncoder().encode(authToken)
  const data = new TextEncoder().encode(payload)
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  )
  const signatureBytes = await crypto.subtle.sign('HMAC', cryptoKey, data)
  const signatureArray = Array.from(new Uint8Array(signatureBytes))
  return btoa(String.fromCharCode(...signatureArray))
}

// This webhook receives status updates from Twilio about ongoing calls
serve(async (req) => {
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('Supabase credentials are not configured')
      return new Response('Server misconfiguration', { status: 500 })
    }

    if (!TWILIO_AUTH_TOKEN) {
      console.error('Twilio auth token is not configured')
      return new Response('Server misconfiguration', { status: 500 })
    }

    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 })
    }

    const contentType = req.headers.get('content-type') || ''
    const bodyText = await req.text()
    const requestUrl = TWILIO_WEBHOOK_URL || req.url

    const providedSignature = req.headers.get('x-twilio-signature') || ''
    if (!providedSignature) {
      console.warn('Missing Twilio signature header')
      return new Response('Forbidden', { status: 403 })
    }

    const expectedSignature = await computeTwilioSignature(
      requestUrl,
      bodyText,
      contentType,
      TWILIO_AUTH_TOKEN,
    )

    if (!timingSafeEqual(providedSignature, expectedSignature)) {
      console.warn('Invalid Twilio signature')
      return new Response('Forbidden', { status: 403 })
    }

    const payload: Record<string, string> = {}
    if (contentType.includes('application/json')) {
      let jsonBody: Record<string, unknown> = {}
      try {
        jsonBody = bodyText ? JSON.parse(bodyText) : {}
      } catch {
        return new Response('Bad Request', { status: 400 })
      }
      for (const [key, value] of Object.entries(jsonBody)) {
        payload[key] = String(value)
      }
    } else {
      const params = new URLSearchParams(bodyText)
      for (const [key, value] of params.entries()) {
        payload[key] = value
      }
    }

    const callSid = payload['CallSid'] || ''
    const callStatus = payload['CallStatus'] || ''
    const duration = payload['CallDuration'] || ''

    if (!callSid || !callStatus) {
      console.warn('Missing required Twilio fields', { callSid, callStatus })
      return new Response('Bad Request', { status: 400 })
    }

    console.log(`Call ${callSid} status: ${callStatus}`)

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Update call status in database
    const updateData: Record<string, unknown> = {
      status: callStatus,
      updated_at: new Date().toISOString(),
    }

    if (callStatus === 'completed' || callStatus === 'failed' || callStatus === 'busy' || callStatus === 'no-answer') {
      updateData.ended_at = new Date().toISOString()
      if (duration) {
        updateData.duration_seconds = parseInt(duration, 10)
      }
    }

    if (callStatus === 'in-progress') {
      updateData.answered_at = new Date().toISOString()
    }

    await supabase.from('phone_calls').update(updateData).eq('call_sid', callSid)

    // Return empty TwiML to acknowledge
    return new Response('<?xml version="1.0" encoding="UTF-8"?><Response></Response>', {
      status: 200,
      headers: {
        'Content-Type': 'application/xml',
      },
    })
  } catch (err) {
    console.error('Webhook error:', err)
    return new Response('Internal Server Error', { status: 500 })
  }
})
