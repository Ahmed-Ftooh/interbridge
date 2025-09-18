import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token'

const APP_ID = Deno.env.get('AGORA_APP_ID')!
const APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE')!

serve(async (req) => {
  const { channelName, uid } = await req.json()

  const expirationTimeInSeconds = 3600
  const currentTimestamp = Math.floor(Date.now() / 1000)
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID,
    APP_CERTIFICATE,
    channelName,
    parseInt(uid),
    RtcRole.PUBLISHER,
    privilegeExpiredTs
  )

  return new Response(JSON.stringify({ token }), {
    headers: { "Content-Type": "application/json" }
  })
})
