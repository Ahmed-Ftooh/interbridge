import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID') || ''
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN') || ''
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER') || ''

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

interface CallRequest {
  action: 'initiate' | 'status' | 'end'
  toPhoneNumber?: string
  callSid?: string
  requestId?: string
  callerId?: string // The doctor/interpreter making the call
}

interface TwilioCallResponse {
  sid: string
  status: string
  to: string
  from: string
  direction: string
  dateCreated: string
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    },
  })
}

// Base64 encode for Basic Auth
function base64Encode(str: string): string {
  return btoa(str)
}

// Make Twilio API request
async function twilioRequest(
  endpoint: string, 
  method: 'GET' | 'POST' | 'DELETE' = 'GET',
  body?: Record<string, string>
): Promise<Response> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}${endpoint}`
  
  const headers: Record<string, string> = {
    'Authorization': `Basic ${base64Encode(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
  }

  const options: RequestInit = { method, headers }

  if (body && method === 'POST') {
    headers['Content-Type'] = 'application/x-www-form-urlencoded'
    options.body = new URLSearchParams(body).toString()
  }

  return fetch(url, options)
}

// Initiate an outbound call
async function initiateCall(
  toPhoneNumber: string, 
  requestId: string,
  callerId: string,
  supabase: ReturnType<typeof createClient>
): Promise<TwilioCallResponse> {
  // TwiML URL for the call - simple connection message
  // You can customize this to connect to a conference, play audio, etc.
  const twimlUrl = `${SUPABASE_URL}/functions/v1/twilio-twiml?requestId=${requestId}`
  
  const response = await twilioRequest('/Calls.json', 'POST', {
    To: toPhoneNumber,
    From: TWILIO_PHONE_NUMBER,
    Url: twimlUrl,
    StatusCallback: `${SUPABASE_URL}/functions/v1/twilio-webhook`,
    StatusCallbackEvent: 'initiated ringing answered completed',
    StatusCallbackMethod: 'POST',
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Twilio API error: ${error}`)
  }

  const callData = await response.json() as TwilioCallResponse

  // Log the call in database
  await supabase.from('phone_calls').insert({
    call_sid: callData.sid,
    request_id: requestId,
    caller_id: callerId,
    to_phone: toPhoneNumber,
    from_phone: TWILIO_PHONE_NUMBER,
    status: callData.status,
    direction: 'outbound',
    created_at: new Date().toISOString(),
  })

  return callData
}

// Get call status
async function getCallStatus(callSid: string): Promise<TwilioCallResponse> {
  const response = await twilioRequest(`/Calls/${callSid}.json`)

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Twilio API error: ${error}`)
  }

  return await response.json() as TwilioCallResponse
}

// End a call
async function endCall(
  callSid: string,
  supabase: ReturnType<typeof createClient>
): Promise<TwilioCallResponse> {
  const response = await twilioRequest(`/Calls/${callSid}.json`, 'POST', {
    Status: 'completed',
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Twilio API error: ${error}`)
  }

  const callData = await response.json() as TwilioCallResponse

  // Update call status in database
  await supabase.from('phone_calls').update({
    status: 'completed',
    ended_at: new Date().toISOString(),
  }).eq('call_sid', callSid)

  return callData
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Only allow POST
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method Not Allowed' }, 405)
    }

    // Validate Twilio credentials
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
      return jsonResponse({
        error: 'Missing Twilio credentials',
        details: 'TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, or TWILIO_PHONE_NUMBER not set',
      }, 500)
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Parse request body
    const body = await req.json() as CallRequest

    switch (body.action) {
      case 'initiate': {
        if (!body.toPhoneNumber || !body.requestId || !body.callerId) {
          return jsonResponse({
            error: 'Missing required fields',
            details: 'toPhoneNumber, requestId, and callerId are required for initiate action',
          }, 400)
        }

        const callData = await initiateCall(
          body.toPhoneNumber, 
          body.requestId,
          body.callerId,
          supabase
        )
        
        return jsonResponse({
          success: true,
          callSid: callData.sid,
          status: callData.status,
          to: callData.to,
          from: callData.from,
        })
      }

      case 'status': {
        if (!body.callSid) {
          return jsonResponse({
            error: 'Missing callSid for status check',
          }, 400)
        }

        const callData = await getCallStatus(body.callSid)
        
        return jsonResponse({
          success: true,
          callSid: callData.sid,
          status: callData.status,
        })
      }

      case 'end': {
        if (!body.callSid) {
          return jsonResponse({
            error: 'Missing callSid for end call',
          }, 400)
        }

        const callData = await endCall(body.callSid, supabase)
        
        return jsonResponse({
          success: true,
          callSid: callData.sid,
          status: callData.status,
        })
      }

      default:
        return jsonResponse({
          error: 'Invalid action',
          details: 'Supported actions: initiate, status, end',
        }, 400)
    }
  } catch (err) {
    console.error('Error:', err)
    return jsonResponse({ 
      error: 'Unexpected error', 
      details: String(err) 
    }, 500)
  }
})
