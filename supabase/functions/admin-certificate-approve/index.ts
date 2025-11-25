// Admin: Approve interpreter certificate (requires admin user)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors() });
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

    const authHeader = req.headers.get("Authorization") ?? "";
    const user = await getAuthenticatedUser(authHeader);
    if (!user) return json({ error: "Unauthorized" }, 401);
    const isAdmin = await ensureIsAdmin(user.id);
    if (!isAdmin) return json({ error: "Forbidden" }, 403);

    const body = await req.json();
    const { certificate_id, approve_note } = body ?? {};
    if (!certificate_id) return json({ error: "Missing certificate_id" }, 400);

    const svc = await serviceClient();
    const update = await svc
      .from("interpreter_certificates")
      .update({ is_verified: true, status: "approved", reviewed_at: new Date().toISOString(), review_note: approve_note ?? null })
      .eq("id", certificate_id)
      .select("id, user_id")
      .maybeSingle();
    if (update.error) throw update.error;

    // Optional: update user verification flag on details/profile
    if (update.data?.user_id) {
      await svc.from("interpreter_details").update({ is_verified: true }).eq("user_id", update.data.user_id);
    }

    return json({ ok: true });
  } catch (e) {
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
}

function json(body: Json, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...cors() } });
}

async function getAuthenticatedUser(authHeader: string) {
  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
    });
    const { data, error } = await supabase.auth.getUser();
    if (error || !data?.user) return null;
    return data.user;
  } catch (_) {
    return null;
  }
}

async function ensureIsAdmin(userId: string) {
  const svc = await serviceClient();
  const { data, error } = await svc.from("users_profile").select("role").eq("user_id", userId).maybeSingle();
  if (error) return false;
  return data?.role === "admin" || data?.role === "superadmin";
}

async function serviceClient() {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  return createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
}
