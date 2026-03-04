// Send Invoice Email — delivers invoice link to organization billing contact
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const { to_email, org_name, invoice_url, total_amount, period, invoice_id } =
      body;

    if (!to_email) {
      return json({ error: "Missing to_email" }, 400);
    }

    // Try Resend first (free tier: 100 emails/day, 3000/month)
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (resendApiKey) {
      const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f1f5f9; margin: 0; padding: 40px 20px; }
    .container { max-width: 560px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #0955FA, #6366F1); padding: 32px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 24px; }
    .header p { color: rgba(255,255,255,0.8); margin: 8px 0 0; }
    .body { padding: 32px; }
    .amount { font-size: 36px; font-weight: 700; color: #0955FA; text-align: center; margin: 24px 0; }
    .period { text-align: center; color: #64748b; margin-bottom: 24px; }
    .btn { display: block; background: #0955FA; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; text-align: center; font-weight: 600; margin: 24px auto; max-width: 240px; }
    .footer { padding: 24px 32px; background: #f8fafc; text-align: center; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>InterBridge Invoice</h1>
      <p>${org_name ?? "Organization"}</p>
    </div>
    <div class="body">
      <p>Hello,</p>
      <p>Your monthly interpretation services invoice is ready.</p>
      <div class="amount">$${(total_amount ?? 0).toFixed(2)}</div>
      <div class="period">${period ?? "Monthly"}</div>
      ${
        invoice_url
          ? `<a href="${invoice_url}" class="btn">View Invoice</a>`
          : ""
      }
      <p style="color:#64748b;font-size:14px;text-align:center">This amount has been deducted from your prepaid wallet. If you use postpaid billing, please remit payment within 30 days.</p>
    </div>
    <div class="footer">
      <p>InterBridge — Medical Interpretation Services</p>
      <p>This is an automated email. Do not reply to this message.</p>
    </div>
  </div>
</body>
</html>`;

      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "InterBridge <invoices@interbridge.app>",
          to: [to_email],
          subject: `InterBridge Invoice — ${period ?? "Monthly"} — $${(
            total_amount ?? 0
          ).toFixed(2)}`,
          html: emailHtml,
        }),
      });

      const result = await res.json();

      if (!res.ok) {
        console.error("Resend API error:", result);
        return json(
          {
            error: result.message ?? "Email send failed",
            fallback: "Email service error — invoice is still accessible via dashboard",
          },
          500
        );
      }

      // Update invoice status to sent
      if (invoice_id) {
        const { createClient } = await import(
          "https://esm.sh/@supabase/supabase-js@2"
        );
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL") ?? "",
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
        );

        await supabase
          .from("invoices")
          .update({
            status: "sent",
            sent_at: new Date().toISOString(),
          })
          .eq("id", invoice_id);
      }

      return json({
        success: true,
        message_id: result.id,
      });
    }

    // No email service configured — log and return success
    // Invoice is still accessible via the dashboard
    console.log(
      `Invoice email would be sent to ${to_email} for $${total_amount} (no RESEND_API_KEY configured)`
    );

    return json({
      success: true,
      message: "Email service not configured — invoice available in dashboard",
      skipped: true,
    });
  } catch (e) {
    console.error("send-invoice-email error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
