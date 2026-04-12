// Admin: Get fresh signed URL for a certificate (requires admin user)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors() });
    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const user = await getAuthenticatedUser(authHeader);
    if (!user) return json({ error: "Unauthorized" }, 401);
    const isAdmin = await ensureIsAdmin(user.id);
    if (!isAdmin) return json({ error: "Forbidden" }, 403);
    if (!hasAdminPortalContext(req)) {
      return json({ error: "Forbidden: Admin portal context required" }, 403);
    }

    const { searchParams } = new URL(req.url);
    let certificateId = searchParams.get("certificate_id");
    let storedUrl = searchParams.get("url");
    if (req.method === "POST") {
      try {
        const body = await req.json();
        certificateId = certificateId ?? body?.certificate_id ?? null;
        storedUrl = storedUrl ?? body?.url ?? null;
      } catch (_) {}
    }
    let bucket: string | null = null;
    let objectPath: string | null = null;

    const svc = await serviceClient();

    if (certificateId) {
      const rec = await svc
        .from("interpreter_certificates")
        .select("url")
        .eq("id", certificateId)
        .maybeSingle();
      if (rec.error) throw rec.error;
      storedUrl = rec.data?.url ?? storedUrl;
    }

    if (!storedUrl) return json({ error: "Missing certificate_id or url" }, 400);

    const parsed = parseStorageUrl(storedUrl);
    bucket = parsed?.bucket ?? null;
    objectPath = parsed?.objectPath ?? null;

    if (!bucket || !objectPath) return json({ error: "Unable to resolve storage path from URL" }, 400);

    const { data, error } = await svc.storage.from(bucket).createSignedUrl(objectPath, 3600);
    if (error) throw error;

    return json({ signed_url: data?.signedUrl ?? null, expires_in: 3600 });
  } catch (e) {
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-portal-context",
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

function hasAdminPortalContext(req: Request) {
  const portalContext = (req.headers.get("x-portal-context") ?? "").trim().toLowerCase();
  return portalContext === "admin";
}

async function serviceClient() {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  return createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
}

function parseStorageUrl(url: string | null | undefined): { bucket: string; objectPath: string } | null {
  if (!url) return null;
  try {
    // Matches both forms:
    // - /storage/v1/object/public/<bucket>/<path>
    // - /storage/v1/object/sign/<bucket>/<path>?token=...
    const m = url.match(/\/object\/(?:public|sign)\/(.*?)\/(.*?)(?:\?|$)/);
    if (m) return { bucket: m[1], objectPath: m[2] };
  } catch (_) {}
  return null;
}
