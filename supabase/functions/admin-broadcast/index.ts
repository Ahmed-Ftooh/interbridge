import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

// Integration Keys
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';
const ONESIGNAL_ENDPOINT = 'https://onesignal.com/api/v1/notifications';

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: Object.assign({}, cors(), {
          "Access-Control-Allow-Methods": "POST, OPTIONS",
        }),
      });
    }

    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    // 1. Authenticate the Admin
    const authHeader = req.headers.get("Authorization") ?? "";
    const adminUser = await getAuthenticatedUser(authHeader);
    if (!adminUser) return json({ error: "Unauthorized" }, 401);
    
    // 2. Validate Admin Context and Role
    if (!hasAdminPortalContext(req)) {
      return json({ error: "Forbidden: Admin portal context required" }, 403);
    }
    const isAdmin = await ensureIsAdmin(adminUser.id);
    if (!isAdmin) return json({ error: "Forbidden: User is not an admin" }, 403);

    // 3. Parse Request Payload
    const body = await req.json();
    const { subject, message, sendEmail, sendPush } = body;

    if (!subject || !message) {
      return json({ error: "Subject and message are required" }, 400);
    }
    
    if (!sendEmail && !sendPush) {
      return json({ error: "No delivery method selected" }, 400);
    }

    const svc = await serviceClient();
    
    console.log("Admin broadcast initiated.");

    // 4. Fetch all verified interpreters
    const { data: verifiedInterpreters, error: vErr } = await svc
      .from("interpreter_details")
      .select("user_id")
      .eq("is_verified", true)
      .eq("is_suspended", false);

    if (vErr) throw vErr;
    if (!verifiedInterpreters || verifiedInterpreters.length === 0) {
      return json({ message: "No verified interpreters found to broadcast to." });
    }

    const interpreterIds = verifiedInterpreters.map(i => i.user_id);
    console.log(`Found ${interpreterIds.length} verified & active interpreters.`);

    let emailsQueued = 0;
    let pushNotificationsSent = false;
    let errors: string[] = [];

    // --- SEND EMAILS ---
    if (sendEmail) {
      // Need their email addresses. Using auth.admin to chunk through them.
      // Easiest is fetching all users iteratively and filtering to interpreterIds set.
      const interpreterIdSet = new Set(interpreterIds);
      let page = 0;
      let hasMore = true;
      const targetEmails = [];

      while (hasMore) {
        const { data: userData, error: authErr } = await (svc as any).auth.admin.listUsers({
          page,
          perPage: 1000
        });
        if (authErr) {
          console.error("Auth chunk fetch error:", authErr);
          break;
        }

        const usersChunk = userData.users || [];
        for (const user of usersChunk) {
          if (interpreterIdSet.has(user.id) && user.email) {
            targetEmails.push(user.email);
          }
        }
        
        hasMore = usersChunk.length === 1000;
        page++;
      }

      console.log(`Sending emails to ${targetEmails.length} addresses via Resend...`);
      
      // Resend allows batch sending using 'to' with max 50 emails per request, or we can loop.
      // Often better to use bcc for broadcast if allowed, but individualized is better.
      // Resend max Bcc limit is 50. Loop through targetEmails in chunks of 50.
      const chunkSize = 50;
      for (let i = 0; i < targetEmails.length; i += chunkSize) {
        const emailChunk = targetEmails.slice(i, i + chunkSize);
        
        try {
          const resendResp = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${RESEND_API_KEY}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              from: "Interbridge Admin <noreply@interbridgehub.com>",
              bcc: emailChunk,
              subject: subject,
              html: `
                <div style="font-family: sans-serif; padding: 20px; color: #333;">
                  <h2>${subject}</h2>
                  <p style="white-space: pre-wrap;">${message}</p>
                  <hr style="margin-top: 30px; border: 0; border-top: 1px solid #eee;" />
                  <p style="font-size: 12px; color: #777;">This is a broadcast message to all verified Interbridge Interpreters.</p>
                </div>
              `,
            })
          });

          if (!resendResp.ok) {
            const errBody = await resendResp.text();
            console.error(`Resend API Error (chunk ${i}):`, errBody);
            errors.push(`Email error chunk ${i}: ${resendResp.status}`);
          } else {
            emailsQueued += emailChunk.length;
          }
        } catch (e) {
          console.error("Fetch email error:", e);
          errors.push(`Email exception chunk ${i}`);
        }
      }
    }

    // --- SEND PUSH NOTIFICATIONS ---
    if (sendPush && ONESIGNAL_APP_ID && ONESIGNAL_REST_API_KEY) {
      console.log(`Sending OneSignal push to ${interpreterIds.length} users...`);
      
      try {
        const payload = {
          app_id: ONESIGNAL_APP_ID,
          include_external_user_ids: interpreterIds, // Send via User IDs
          headings: { en: subject },
          contents: { en: message },
        };

        const pushResp = await fetch(ONESIGNAL_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`
          },
          body: JSON.stringify(payload)
        });

        if (!pushResp.ok) {
          const errBody = await pushResp.text();
          console.error("OneSignal API Error:", errBody);
          errors.push(`Push API error: ${pushResp.status}`);
        } else {
          pushNotificationsSent = true;
        }
      } catch (e) {
        console.error("Fetch push error:", e);
        errors.push(`Push exception: ${e?.message}`);
      }
    }

    return json({
      success: true,
      deliveredToCounts: {
        emails: emailsQueued,
        pushSent: pushNotificationsSent,
        totalEligibleInterpreters: interpreterIds.length,
      },
      errors: errors.length > 0 ? errors : undefined
    });

  } catch (e) {
    console.error("Broadcast Exception:", e);
    return json({ error: e?.message ?? String(e) }, 500);
  }
});

// --- Helpers ---

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-portal-context",
  };
}

function json(body: Json, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors() },
  });
}

function hasAdminPortalContext(req: Request): boolean {
  return req.headers.get("x-portal-context")?.toLowerCase() === "admin";
}

async function serviceClient() {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );
}

async function getAuthenticatedUser(authHeader: string) {
  if (!authHeader) return null;
  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
    });
    const { data, error } = await supabase.auth.getUser();
    if (error || !data?.user) return null;
    return data.user;
  } catch (e) {
    return null;
  }
}

async function ensureIsAdmin(userId: string) {
  try {
    const svc = await serviceClient();
    const { data, error } = await svc
      .from("users_profile")
      .select("role")
      .eq("user_id", userId)
      .single();
    if (error || !data) return false;
    return data.role === "admin";
  } catch (e) {
    return false;
  }
}