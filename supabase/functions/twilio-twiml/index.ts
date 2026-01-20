import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// This function returns TwiML instructions for the outbound call
// When the patient answers, they hear a message

serve(async (req) => {
  try {
    const url = new URL(req.url)
    const requestId = url.searchParams.get('requestId') || 'unknown'

    // TwiML response - customize this message as needed
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice" language="en-US">
    Hello, you are receiving a call from your healthcare provider through Interbridge. 
    Please hold while we connect you to your doctor and interpreter.
  </Say>
  <Pause length="1"/>
  <Say voice="alice" language="en-US">
    You are now connected. The doctor and interpreter can hear you.
  </Say>
  <Pause length="3600"/>
</Response>`

    return new Response(twiml, {
      status: 200,
      headers: {
        'Content-Type': 'application/xml',
      },
    })
  } catch (err) {
    console.error('TwiML error:', err)
    
    // Return a simple error TwiML
    const errorTwiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice">Sorry, there was an error connecting your call. Please try again later.</Say>
  <Hangup/>
</Response>`

    return new Response(errorTwiml, {
      status: 200,
      headers: {
        'Content-Type': 'application/xml',
      },
    })
  }
})
