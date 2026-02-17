// Find available interpreters by language and type
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors });
  if (req.method !== "GET" && req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { "Content-Type": "application/json", ...cors } });

  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");

    let body: any = {};
    if (req.method === "POST") { try { body = await req.json(); } catch {} }
    const fromLang = body.from_language_id ?? Number(new URL(req.url).searchParams.get("from_language_id"));
    const toLang = body.to_language_id ?? Number(new URL(req.url).searchParams.get("to_language_id"));
    const employment = body.employment_type ?? new URL(req.url).searchParams.get("employment_type"); // volunteer|paid

    // Query interpreters matching language ids
    const { data: candidates, error } = await supabase
      .rpc("find_interpreters_by_languages", { p_from_lang: fromLang, p_to_lang: toLang });
    if (error) throw error;

    // Filter by employment type and online/on-shift
    const filtered = (candidates ?? []).filter((c: any) => {
      if (employment && c.employment_type !== employment) return false;
      return c.is_online === true || c.is_on_shift === true;
    });

    return new Response(JSON.stringify({ interpreters: filtered }), { status: 200, headers: { "Content-Type": "application/json", ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500, headers: { "Content-Type": "application/json", ...cors } });
  }
});
