// Auto-Route Call — picks the best interpreter automatically
// Called after pre-call intake form is submitted
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const {
      request_id,
      from_language,
      to_language,
      specialization,
      organization_id,
    } = body;

    if (!request_id || !from_language || !to_language) {
      return json({
        error: "Missing required fields: request_id, from_language, to_language",
      }, 400);
    }

    // Call the DB function to auto-route
    const { data, error } = await supabase.rpc("auto_route_interpreter", {
      p_request_id: request_id,
      p_from_language: from_language,
      p_to_language: to_language,
      p_specialization: specialization || null,
      p_organization_id: organization_id || null,
    });

    if (error) {
      console.error("auto_route_interpreter error:", error);
      return json({ error: error.message }, 500);
    }

    const result = data as Record<string, unknown>;

    // If matched, send push notification to the interpreter to auto-accept
    if (result.status === "matched" || result.status === "overflow") {
      const interpreterId = result.interpreter_id as string;

      // Get interpreter's OneSignal player IDs
      const { data: playerRows } = await supabase
        .from("onesignal_player_ids")
        .select("player_id")
        .eq("user_id", interpreterId);

      const playerIds = (playerRows ?? [])
        .map((r: { player_id: string }) => r.player_id)
        .filter((id: string) => id);

      if (playerIds.length > 0) {
        // Get language names for notification
        const { data: fromLang } = await supabase
          .from("languages")
          .select("name")
          .eq("id", from_language)
          .single();
        const { data: toLang } = await supabase
          .from("languages")
          .select("name")
          .eq("id", to_language)
          .single();

        const fromName = fromLang?.name ?? from_language;
        const toName = toLang?.name ?? to_language;

        // Send notification to matched interpreter
        try {
          await supabase.functions.invoke("send-notification", {
            body: {
              title: "Incoming Call — Auto-Assigned",
              body: `${fromName} → ${toName}${specialization ? ` (${specialization})` : ""}`,
              data: {
                request_id,
                from_language: fromName,
                to_language: toName,
                type: "INCOMING_CALL",
                auto_routed: "true",
                caller_name: `${fromName} → ${toName}`,
                caller_id: request_id,
              },
              player_ids: playerIds,
            },
          });
        } catch (notifErr) {
          console.error("Notification error (non-fatal):", notifErr);
        }
      }

      // Auto-accept the request on behalf of the interpreter
      const { error: acceptErr } = await supabase
        .from("interpreter_requests")
        .update({
          status: "accepted",
          accepted_by: interpreterId,
          accepted_at: new Date().toISOString(),
        })
        .eq("id", request_id)
        .eq("status", "pending");

      if (acceptErr) {
        console.error("Auto-accept error:", acceptErr);
        return json({ error: "Failed to auto-accept: " + acceptErr.message }, 500);
      }
    }

    return json(result);
  } catch (e) {
    console.error("auto-route-call error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
