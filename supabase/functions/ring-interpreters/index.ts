// Create call request and ring interpreters via OneSignal
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { "Content-Type": "application/json", ...cors } });

  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
    const body = await req.json();

    const callerId = body.caller_id;
    const interpreters = body.interpreters ?? [];
    const channelId = body.channel_id; // pre-generated client or server side

    // Insert call_request
    const { data: callReq, error: insertErr } = await supabase
      .from("call_requests")
      .insert({ caller_id: callerId, status: "ringing", channel_id: channelId })
      .select("id").single();
    if (insertErr) throw insertErr;

    // Fetch OneSignal player IDs
    const { data: playerIds } = await supabase
      .from("onesignal_player_ids")
      .select("user_id, player_id")
      .in("user_id", interpreters.map((i: any) => i.user_id));

    // Send notification via send-notification function
    const notifyRes = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/send-notification`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` },
      body: JSON.stringify({
        title: "Incoming Call",
        body: "You have an incoming call request",
        player_ids: (playerIds ?? []).map((p: any) => p.player_id),
        data: { type: "INCOMING_CALL", channel_id: channelId, call_request_id: callReq.id },
      }),
    });

    return new Response(JSON.stringify({ call_request_id: callReq.id, notified: notifyRes.ok }), { status: 200, headers: { "Content-Type": "application/json", ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500, headers: { "Content-Type": "application/json", ...cors } });
  }
});
