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
    if (!hasAdminPortalContext(req)) {
      return json({ error: "Forbidden: Admin portal context required" }, 403);
    }

    const url = new URL(req.url);
    let limit = Math.max(1, Math.min(100, Number(url.searchParams.get("limit")) || 50));
    let offset = Math.max(0, Number(url.searchParams.get("offset")) || 0);
    let search = (url.searchParams.get("search") || "").trim();
    let filterStatus = (url.searchParams.get("status") || "all").trim();
    let filterAccount = (url.searchParams.get("account") || "all").trim();

    if (req.method === "POST") {
      try {
        const body = await req.json();
        if (typeof body?.limit === "number") {
          limit = Math.max(1, Math.min(100, Number(body.limit)));
        }
        if (typeof body?.offset === "number") {
          offset = Math.max(0, Number(body.offset));
        }
        if (typeof body?.search === "string") {
          search = body.search.trim();
        }
        if (typeof body?.status === "string") {
          filterStatus = body.status.trim();
        }
        if (typeof body?.account === "string") {
          filterAccount = body.account.trim();
        }
      } catch (_) {
        // ignore malformed JSON; fallback to query params
      }
    }

    const svc = await serviceClient();
    
    // Join with interpreter_details to get verification and suspension status
    let query = svc
      .from("users_profile")
      .select(`
        user_id, 
        username, 
        role,
        interpreter_details!inner(is_verified, is_suspended)
      `)
      .eq("role", "interpreter")
      .order("username")
      .range(offset, offset + limit - 1);

    if (search) {
      // Case-insensitive match on username
      let orQuery = `username.ilike.%${search}%`;
      // If the search string is purely numerical, it might be the derived Interpreter ID
      const isNumeric = /^\d+$/.test(search);
      if (isNumeric) {
        try {
          const numId = parseInt(search, 10);
          if (!isNaN(numId)) {
            const hexStr = numId.toString(16).toLowerCase();
            if (hexStr.length <= 8) {
              const uuidPrefix = hexStr.padStart(8, '0');
              const lowerBound = `${uuidPrefix}-0000-0000-0000-000000000000`;
              const upperBound = `${uuidPrefix}-ffff-ffff-ffff-ffffffffffff`;
              // Try to match the UUID range using gte and lte to avoid casting issues in PostgREST
              orQuery += `,and(user_id.gte.${lowerBound},user_id.lte.${upperBound})`;
            }
          }
        } catch (_) {}
      }
      query = query.or(orQuery);
    }

    // Apply status filter (verified/unverified)
    if (filterStatus === "verified") {
      query = query.eq("interpreter_details.is_verified", true);
    } else if (filterStatus === "unverified") {
      query = query.or("is_verified.is.null,is_verified.eq.false", { referencedTable: 'interpreter_details' });
    }

    // Apply account filter (active/suspended)
    if (filterAccount === "active") {
      query = query.or("is_suspended.is.null,is_suspended.eq.false", { referencedTable: 'interpreter_details' });
    } else if (filterAccount === "suspended") {
      query = query.eq("interpreter_details.is_suspended", true);
    }

    const { data, error } = await query;
    if (error) throw error;

    // Flatten the response for easier consumption
    const items = (data ?? []).map((item: any) => ({
      user_id: item.user_id,
      username: item.username,
      role: item.role,
      is_verified: item.interpreter_details?.is_verified ?? false,
      is_suspended: item.interpreter_details?.is_suspended ?? false,
    }));

    return json({ items });
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

function hasAdminPortalContext(req: Request) {
  const portalContext = (req.headers.get("x-portal-context") ?? "").trim().toLowerCase();
  return portalContext === "admin";
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
