// Admin: Get interpreter full details (requires admin user)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 200, headers: cors() });
    }
    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const user = await getAuthenticatedUser(authHeader);
    if (!user) return json({ error: "Unauthorized" }, 401);
    const isAdmin = await ensureIsAdmin(user.id);
    if (!isAdmin) return json({ error: "Forbidden" }, 403);

    const { searchParams } = new URL(req.url);
    let id = searchParams.get("id");
    if (!id && req.method === "POST") {
      try {
        const body = await req.json();
        id = body?.id ?? null;
      } catch (_) {}
    }
    if (!id) return json({ error: "Missing id" }, 400);

    const svc = await serviceClient();

    // Get user profile from users_profile table
    const profile = await svc.from("users_profile").select("user_id, username, role, gender, created_at").eq("user_id", id).maybeSingle();
    if (profile.error) throw profile.error;

    // Get email from auth.users table using admin API
    let email = null;
    try {
      const { data: authUser, error: authError } = await svc.auth.admin.getUserById(id);
      if (!authError && authUser?.user?.email) {
        email = authUser.user.email;
      }
    } catch (e) {
      console.error("Error fetching email from auth:", e);
    }

    const details = await svc.from("interpreter_details").select("*").eq("user_id", id).maybeSingle();
    const langs = await svc
      .from("interpreter_languages")
      .select("language_id, languages(name)")
      .eq("user_id", id);
    const skills = await svc
      .from("interpreter_skills")
      .select("skill_id, skills(name)")
      .eq("user_id", id);
    const specs = await svc
      .from("interpreter_specializations")
      .select("specialization_id, specializations(name)")
      .eq("user_id", id);
    const certs = await svc
      .from("interpreter_certificates")
      .select("id, url, file_name, certificate_type, uploaded_at, is_verified, status")
      .eq("user_id", id)
      .order("uploaded_at", { ascending: false });

    // Attempt to re-sign certificate URLs if expired (parse bucket + path from stored url if possible)
    let certificates = certs.data || [];
    certificates = await Promise.all(
      certificates.map(async (c: any) => ({ ...c, url: await ensureSignedUrl(c.url) }))
    );

    return json({
      profile: { ...profile.data, email }, // Add email to profile object
      details: details.data ?? null,
      languages: langs.data ?? [],
      skills: skills.data ?? [],
      specializations: specs.data ?? [],
      certificates,
    });
  } catch (e) {
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
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
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  return createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
}

async function ensureSignedUrl(storedUrl: string | null | undefined): Promise<string | null> {
  if (!storedUrl) return null;
  try {
    // Expected signed format: /object/sign/<bucket>/<path>?token=...
    const match = storedUrl.match(/\/object\/sign\/(.*?)\/(.*?)(\?|$)/);
    if (!match) return storedUrl; // fallback to stored url
    const bucket = match[1];
    const objectPath = match[2];

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const svc = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
    const { data, error } = await svc.storage.from(bucket).createSignedUrl(objectPath, 3600);
    if (error) return storedUrl;
    return data?.signedUrl ?? storedUrl;
  } catch (_) {
    return storedUrl;
  }
}
