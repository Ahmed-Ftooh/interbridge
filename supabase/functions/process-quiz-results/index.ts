// Process quiz results and store attempts; badges awarded by trigger
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
    const auth = req.headers.get("Authorization") ?? "";
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", { global: { headers: { Authorization: auth } } });
    const body = await req.json();

    const attempt = {
      quiz_type: body.quiz_type, // 'general'|'medical'
      medical_section: body.medical_section ?? null,
      total_questions: body.total_questions,
      correct_answers: body.correct_answers,
      score_percentage: body.score_percentage,
      time_taken_seconds: body.time_taken_seconds,
      passed: body.passed,
      answers: body.answers ?? null,
    };

    const userRes = await supabase.auth.getUser();
    if (!userRes.data.user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { "Content-Type": "application/json", ...cors } });

    const { error } = await supabase.from("quiz_attempts").insert({ ...attempt, user_id: userRes.data.user.id });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { "Content-Type": "application/json", ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), { status: 500, headers: { "Content-Type": "application/json", ...cors } });
  }
});
