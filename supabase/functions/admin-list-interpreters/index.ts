// Admin: List interpreters (requires admin user). Uses service role for DB reads.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: cors(),
      });
    }

    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const adminUser = await getAuthenticatedUser(authHeader);
    if (!adminUser) return json({ error: "Unauthorized" }, 401);
    const isAdmin = await ensureIsAdmin(adminUser.id);
    if (!isAdmin) return json({ error: "Forbidden" }, 403);

    const url = new URL(req.url);
    let limit = Math.max(1, Math.min(100, Number(url.searchParams.get("limit")) || 50));
    let search = (url.searchParams.get("search") || "").trim();

    if (req.method === "POST") {
      try {
        const body = await req.json();
        if (typeof body?.limit === "number") {
          limit = Math.max(1, Math.min(100, Number(body.limit)));
        }
        if (typeof body?.search === "string") {
          search = body.search.trim();
        }
      } catch (_) {
        // ignore malformed JSON; fallback to query params
      }
    }

    const svc = await serviceClient();
    // Basic list: users_profile with role = 'interpreter'
    let query = svc.from("users_profile").select("user_id, username, role").eq("role", "interpreter").order("username").limit(limit);
    if (search) {
      // Case-insensitive match on username
      query = query.ilike("username", `%${search}%`);
    }
    const { data, error } = await query;
    if (error) throw error;

    return json({ items: data ?? [] });
  } catch (e) {
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
  };
}

function json(body: Json, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors() },
  });
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
  const { data, error } = await svc
    .from("users_profile")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) return false;
  return data?.role === "admin" || data?.role === "superadmin";
}

async function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const { createClient } = (globalThis as any).supabase_js || {};
  if (createClient) {
    return createClient(url, key);
  }
  const mod: any = await import("https://esm.sh/@supabase/supabase-js@2");
  return mod.createClient(url, key);
}
