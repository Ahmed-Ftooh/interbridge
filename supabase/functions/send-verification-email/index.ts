import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

interface VerificationEmailRequest {
  to: string;
  interpreterName: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  try {
    const requestBody = await req.json();
    console.log("Received verification email request:", requestBody);

    let data: VerificationEmailRequest;
    if (requestBody.body && typeof requestBody.body === "object") {
      data = requestBody.body;
    } else if (requestBody.body && typeof requestBody.body === "string") {
      data = JSON.parse(requestBody.body);
    } else {
      data = requestBody;
    }

    const { to, interpreterName } = data;

    if (!to) {
      return new Response(
        JSON.stringify({ error: "Missing required field: to" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!RESEND_API_KEY) {
      console.log(
        "RESEND_API_KEY not configured, returning mock success"
      );
      return new Response(
        JSON.stringify({
          success: true,
          message:
            "Email would be sent in production (RESEND_API_KEY not configured)",
          mockData: { to, interpreterName },
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const emailHtml = buildVerificationEmailHtml(interpreterName || "there");

    console.log(`Sending verification email to ${to}...`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "InterBridge <onboarding@resend.dev>",
        to: [to],
        subject: "You've Been Verified on InterBridge!",
        html: emailHtml,
      }),
    });

    if (!resendResponse.ok) {
      const errorData = await resendResponse.text();
      console.error("Resend API error:", errorData);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: errorData }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const result = await resendResponse.json();
    console.log("Verification email sent successfully:", result);

    return new Response(
      JSON.stringify({ success: true, messageId: result.id, to }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in send-verification-email function:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

function buildVerificationEmailHtml(name: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>You're Verified on InterBridge</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table role="presentation" style="width: 100%; border-collapse: collapse;">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <table role="presentation" style="width: 100%; max-width: 600px; border-collapse: collapse; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
          <!-- Header -->
          <tr>
            <td style="padding: 40px 40px 30px; text-align: center; background: linear-gradient(135deg, #10B981 0%, #059669 100%); border-radius: 12px 12px 0 0;">
              <div style="width: 64px; height: 64px; margin: 0 auto 16px; background-color: rgba(255,255,255,0.2); border-radius: 50%; line-height: 64px; font-size: 32px;">&#10003;</div>
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">You're Verified!</h1>
              <p style="margin: 10px 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">InterBridge Interpreter</p>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 40px;">
              <h2 style="margin: 0 0 20px; color: #333333; font-size: 22px; font-weight: 600;">
                Congratulations, ${name}!
              </h2>

              <p style="margin: 0 0 20px; color: #555555; font-size: 16px; line-height: 1.6;">
                We're pleased to let you know that your interpreter profile on <strong>InterBridge</strong> has been reviewed and <strong>verified</strong> by our admin team.
              </p>

              <!-- What's Next Box -->
              <div style="background-color: #f0fdf4; border-left: 4px solid #10B981; border-radius: 0 8px 8px 0; padding: 20px; margin-bottom: 24px;">
                <h3 style="margin: 0 0 12px; color: #065f46; font-size: 16px; font-weight: 600;">What Happens Next?</h3>
                <p style="margin: 0; color: #555555; font-size: 14px; line-height: 1.6;">
                  A member of our team will reach out to you shortly to schedule your onboarding session. During onboarding we'll walk you through the platform, answer any questions, and let you know when you can start receiving interpretation calls.
                </p>
              </div>

              <p style="margin: 0 0 24px; color: #555555; font-size: 16px; line-height: 1.6;">
                In the meantime, make sure to keep the InterBridge app installed and your notifications enabled so you don't miss any updates from us.
              </p>

              <!-- Divider -->
              <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 30px 0;">

              <p style="margin: 0; color: #999999; font-size: 13px; line-height: 1.6;">
                If you have any questions before we reach out, feel free to reply to this email or contact us at <a href="mailto:support@interbridge.app" style="color: #10B981; text-decoration: none;">support@interbridge.app</a>.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 40px; background-color: #f9fafb; border-radius: 0 0 12px 12px; text-align: center;">
              <p style="margin: 0 0 4px; color: #9ca3af; font-size: 12px;">InterBridge &mdash; Healthcare Interpretation Services</p>
              <p style="margin: 0; color: #9ca3af; font-size: 12px;">&copy; ${new Date().getFullYear()} InterBridge. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}
