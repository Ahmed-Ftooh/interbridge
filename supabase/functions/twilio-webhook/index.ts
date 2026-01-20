import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

// This webhook receives status updates from Twilio about ongoing calls
serve(async (req) => {
  try {
    // Parse form data from Twilio
    const formData = await req.formData()
    
    const callSid = formData.get('CallSid') as string
    const callStatus = formData.get('CallStatus') as string
    const from = formData.get('From') as string
    const to = formData.get('To') as string
    const duration = formData.get('CallDuration') as string
    const timestamp = formData.get('Timestamp') as string

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
    return new Response('<?xml version="1.0" encoding="UTF-8"?><Response></Response>', {
      status: 200,
      headers: {
        'Content-Type': 'application/xml',
      },
    })
  }
})
