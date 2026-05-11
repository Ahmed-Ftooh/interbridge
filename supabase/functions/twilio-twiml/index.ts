import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
// Import the official Agora Token generator for Deno/Supabase
import { RtcTokenBuilder, RtcRole } from 'npm:agora-token'

const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID') || 'd561821cc6244180a0d44e1f2eb7de84'
const AGORA_APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE') || 'e32f1b349ddf432fb39af4d87c41b6c6'

serve(async (req) => {
  try {
    const url = new URL(req.url)
    // In your app, the requestId is used as the Agora Channel Name
    const requestId = url.searchParams.get('requestId') || 'unknown'

    // 1. Generate the Secure Agora Token for Twilio
    const uid = 0; // 0 tells Agora to automatically assign an ID to the phone call
    const role = RtcRole.PUBLISHER;
    const expirationInSeconds = 3600; // The token is valid for 1 hour
    
    let agoraToken = '';
    
    if (AGORA_APP_ID && AGORA_APP_CERTIFICATE) {
      agoraToken = RtcTokenBuilder.buildTokenWithUid(
        AGORA_APP_ID,
        AGORA_APP_CERTIFICATE,
        requestId,
        uid,
        role,
        expirationInSeconds,
        expirationInSeconds
      );
    } else {
      throw new Error('Missing Agora App ID or Certificate in Supabase Secrets');
    }

    // 2. Build the SIP URI with the Token attached
    // VERY IMPORTANT: In XML, the "&" symbol must be written as "&amp;" 
const sipUri = `sip:${requestId}@sip.agora.io?appid=${AGORA_APP_ID}&amp;token=${encodeURIComponent(agoraToken)}`;
    // 3. Generate the TwiML Instructions for Twilio
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice" language="en-US">
    Hello, you are receiving a call from your healthcare provider through Interbridge. 
    Please hold while we connect you to your doctor.
  </Say>
  <Dial>
    <!-- Twilio passes the channel name, App ID, and newly generated Token to Agora -->
    <Sip>${sipUri}</Sip>
  </Dial>
</Response>`

    return new Response(twiml, {
      status: 200,
      headers: {
        'Content-Type': 'application/xml',
      },
    })
  } catch (err) {
    console.error('TwiML error:', err)
    
    // If token generation fails, Twilio will play this error to the patient instead of crashing
    const errorTwiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice">Sorry, there was an error securing your connection. Please try again later.</Say>
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