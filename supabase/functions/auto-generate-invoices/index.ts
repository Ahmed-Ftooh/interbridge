// Auto-generate monthly invoices for all active organizations
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

function getPreviousMonthUtc() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  const target = new Date(Date.UTC(year, month - 1, 1));
  return {
    year: target.getUTCFullYear(),
    month: target.getUTCMonth() + 1,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: cors });
  }
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  const cronSecret = Deno.env.get("INVOICE_CRON_SECRET") ?? "";
  const provided = req.headers.get("x-cron-secret") ?? "";
  const authHeader = req.headers.get("authorization") ?? "";

  // Require either the cron secret OR a valid bearer token
  const hasCronSecret = cronSecret && provided === cronSecret;
  const hasBearer = authHeader.startsWith("Bearer ");

  if (!hasCronSecret && !hasBearer) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => null);
    const defaults = getPreviousMonthUtc();
    const year = Number(body?.year ?? defaults.year);
    const month = Number(body?.month ?? defaults.month);
    const organizationId = body?.organization_id ?? null;

    if (!Number.isFinite(year) || !Number.isFinite(month)) {
      return json({ error: "Invalid year/month" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let orgQuery = supabase
      .from("organizations")
      .select("id")
      .eq("is_active", true);
    if (organizationId) {
      orgQuery = orgQuery.eq("id", organizationId);
    }

    const { data: orgs, error } = await orgQuery;
    if (error) {
      return json({ error: error.message }, 500);
    }

    let generated = 0;
    let skipped = 0;
    let failed = 0;

    for (const org of (orgs ?? []) as Array<Record<string, unknown>>) {
      try {
        const response = await supabase.functions.invoke("generate-invoice", {
          body: {
            organization_id: org.id,
            year,
            month,
            send_email: true,
          },
        });

        if (response.status !== 200) {
          failed++;
          continue;
        }

        const data = response.data as Record<string, unknown> | null;
        if (data?.status === "no_data") {
          skipped++;
        } else {
          generated++;
        }
      } catch (e) {
        console.error("auto-generate-invoices error:", e);
        failed++;
      }
    }

    return json({
      status: "ok",
      year,
      month,
      total_orgs: (orgs ?? []).length,
      generated,
      skipped,
      failed,
    });
  } catch (e) {
    console.error("auto-generate-invoices error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
