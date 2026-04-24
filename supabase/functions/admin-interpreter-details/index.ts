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
    if (!hasAdminPortalContext(req)) {
      return json({ error: "Forbidden: Admin portal context required" }, 403);
    }

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
    const profile = await svc.from("users_profile").select(`
      user_id, 
      username, 
      role, 
      gender, 
      country,
      profile_image,
      institution_id,
      created_at
    `).eq("user_id", id).maybeSingle();
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

    // Get all quiz attempts (quiz results with scores + anti-cheat fields)
    const quizAttempts = await svc
      .from("quiz_attempts")
      .select("id, quiz_type, medical_section, total_questions, correct_answers, score_percentage, time_taken_seconds, passed, taken_at, tab_switches, copy_paste_attempts, screenshot_attempts, session_start_at, session_end_at, browser_info, is_flagged")
      .eq("user_id", id)
      .order("taken_at", { ascending: false });

    // Deduplicate quiz attempts: keep only the latest attempt per quiz_type + medical_section
    const quizData = quizAttempts.data ?? [];
    const quizMap = new Map<string, any>();
    for (const qa of quizData) {
      const key = `${qa.quiz_type ?? ""}::${qa.medical_section ?? ""}`;
      if (!quizMap.has(key)) {
        quizMap.set(key, qa);
      }
      // already sorted desc by taken_at, so first occurrence is the latest
    }
    const dedupedQuizAttempts = Array.from(quizMap.values());

    // Get government IDs
    const governmentIds = await svc
      .from("government_ids")
      .select("id, file_url, file_name, status, uploaded_at, reviewer_notes")
      .eq("user_id", id)
      .order("uploaded_at", { ascending: false });

    // Get phone verification status.
    // There may be multiple rows over time, so do not use maybeSingle().
    const phoneVerificationRows = await svc
      .from("phone_verifications")
      .select("id, phone_number, verified, verified_at, email")
      .eq("user_id", id)
      .order("verified", { ascending: false })
      .order("verified_at", { ascending: false })
      .limit(5);

    // Optional fallback from profile/details in case phone_verifications is empty.
    let fallbackPhoneNumber: string | null = null;
    let fallbackPhoneVerified = false;

    try {
      const profilePhone = await svc
        .from("users_profile")
        .select("phone_number, phone_verified")
        .eq("user_id", id)
        .maybeSingle();

      if (!profilePhone.error && profilePhone.data) {
        fallbackPhoneNumber = profilePhone.data.phone_number ?? null;
        fallbackPhoneVerified = profilePhone.data.phone_verified === true;
      }
    } catch (_) {
      // Ignore environments where these optional columns do not exist.
    }

    if (!fallbackPhoneNumber && details.data && typeof details.data === "object") {
      const d = details.data as Record<string, unknown>;
      const detailsPhone = (d.phone_number ?? d.phone) as string | null | undefined;
      if (typeof detailsPhone === "string" && detailsPhone.trim().length > 0) {
        fallbackPhoneNumber = detailsPhone;
      }
      if (d.phone_verified === true) {
        fallbackPhoneVerified = true;
      }
    }

    let phoneVerificationData: Record<string, unknown> | null = null;
    if (!phoneVerificationRows.error && Array.isArray(phoneVerificationRows.data) && phoneVerificationRows.data.length > 0) {
      phoneVerificationData = phoneVerificationRows.data[0] as Record<string, unknown>;
    } else if (fallbackPhoneNumber) {
      phoneVerificationData = {
        id: null,
        phone_number: fallbackPhoneNumber,
        verified: fallbackPhoneVerified,
        verified_at: null,
        email,
        source: "profile_fallback",
      };
    }

    // Get all earned badges
    const badges = await svc
      .from("interpreter_badges")
      .select("id, badge, score, earned_at")
      .eq("user_id", id)
      .order("earned_at", { ascending: false });

    // Fetch voice samples from DB table (metadata + URLs stored on upload)
    const voiceSamplesQuery = await svc
      .from("voice_samples")
      .select("id, url, prompt, sentence_type, file_size, created_at, is_verified")
      .eq("user_id", id)
      .order("created_at", { ascending: false });

    // Generate fresh signed URLs for each voice sample
    let voiceSamplesList: any[] = [];
    try {
      const rows = voiceSamplesQuery.data ?? [];
      voiceSamplesList = await Promise.all(
        rows.map(async (row: any) => {
          let signedUrl: string | null = null;
          if (row.url) {
            // Extract object path from either public or signed storage URL.
            // Works for both:
            // .../storage/v1/object/public/voice_samples/{path}
            // .../storage/v1/object/sign/voice_samples/{path}?token=...
            // and older variants without /storage/v1 prefix.
            const pathMatch = row.url.match(
              /(?:\/storage\/v1)?\/object\/(?:sign|public)\/voice_samples\/(.+?)(?:\?|$)/
            );
            if (pathMatch) {
              const objectPath = pathMatch[1];
              const { data: sd } = await svc.storage
                .from("voice_samples")
                .createSignedUrl(objectPath, 3600);
              signedUrl = sd?.signedUrl ?? row.url ?? null;
            } else {
              signedUrl = row.url;
            }
          }
          return {
            id: row.id,
            prompt: row.prompt,
            sentence_type: row.sentence_type,
            file_size: row.file_size,
            url: signedUrl,
            created_at: row.created_at,
            is_verified: row.is_verified,
          };
        })
      );
      voiceSamplesList = voiceSamplesList.filter((v: any) => v.url);
    } catch (e) {
      console.error("Error processing voice samples:", e);
    }

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
      voiceSamples: voiceSamplesList,
      quizAttempts: dedupedQuizAttempts,
      badges: badges.data ?? [],
      governmentIds: governmentIds.data ?? [],
      phoneVerification: phoneVerificationData,
    });
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
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  return createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
}

async function ensureSignedUrl(storedUrl: string | null | undefined): Promise<string | null> {
  if (!storedUrl) return null;
  try {
    // Handle both signed and public storage URLs.
    const match = storedUrl.match(/(?:\/storage\/v1)?\/object\/(?:sign|public)\/(.*?)\/(.*?)(\?|$)/);
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
