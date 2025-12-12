// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

interface InviteEmailRequest {
  to: string;
  inviteCode: string;
  organizationName: string;
  inviterName?: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const requestBody = await req.json();
    console.log("Received invite email request:", requestBody);

    // Extract data - handle potential wrapper objects
    let data: InviteEmailRequest;
    if (requestBody.body && typeof requestBody.body === "object") {
      data = requestBody.body;
    } else if (requestBody.body && typeof requestBody.body === "string") {
      data = JSON.parse(requestBody.body);
    } else {
      data = requestBody;
    }

    const { to, inviteCode, organizationName, inviterName } = data;

    // Validate required fields
    if (!to || !inviteCode || !organizationName) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: to, inviteCode, organizationName" 
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if Resend API key is configured
    if (!RESEND_API_KEY) {
      console.log("RESEND_API_KEY not configured, returning mock success");
      return new Response(
        JSON.stringify({
          success: true,
          message: "Email would be sent in production (RESEND_API_KEY not configured)",
          mockData: { to, inviteCode, organizationName }
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build the email HTML
    const emailHtml = buildInviteEmailHtml({
      inviteCode,
      organizationName,
      inviterName: inviterName || "An administrator",
    });

    // Send email via Resend
    console.log(`Sending invite email to ${to}...`);
    
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "InterBridge <onboarding@resend.dev>",
        to: [to],
        subject: `You've been invited to join ${organizationName} on InterBridge`,
        html: emailHtml,
      }),
    });

    if (!resendResponse.ok) {
      const errorData = await resendResponse.text();
      console.error("Resend API error:", errorData);
      return new Response(
        JSON.stringify({ 
          error: "Failed to send email", 
          details: errorData 
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = await resendResponse.json();
    console.log("Email sent successfully:", result);

    return new Response(
      JSON.stringify({ 
        success: true, 
        messageId: result.id,
        to 
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error in send-invite-email function:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error", 
        details: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function buildInviteEmailHtml({
  inviteCode,
  organizationName,
  inviterName,
}: {
  inviteCode: string;
  organizationName: string;
  inviterName: string;
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>You're Invited to InterBridge</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table role="presentation" style="width: 100%; border-collapse: collapse;">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <table role="presentation" style="width: 100%; max-width: 600px; border-collapse: collapse; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
          <!-- Header -->
          <tr>
            <td style="padding: 40px 40px 30px; text-align: center; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px 12px 0 0;">
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600;">InterBridge</h1>
              <p style="margin: 10px 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">Healthcare Interpretation Services</p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px;">
              <h2 style="margin: 0 0 20px; color: #333333; font-size: 24px; font-weight: 600;">You're Invited!</h2>
              
              <p style="margin: 0 0 20px; color: #555555; font-size: 16px; line-height: 1.6;">
                ${inviterName} has invited you to join <strong>${organizationName}</strong> on InterBridge as a healthcare provider.
              </p>
              
              <p style="margin: 0 0 30px; color: #555555; font-size: 16px; line-height: 1.6;">
                Use the invite code below to join the organization and start connecting with professional medical interpreters.
              </p>
              
              <!-- Invite Code Box -->
              <div style="background-color: #f8f9fa; border: 2px dashed #667eea; border-radius: 8px; padding: 25px; text-align: center; margin-bottom: 30px;">
                <p style="margin: 0 0 10px; color: #666666; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Your Invite Code</p>
                <p style="margin: 0; color: #667eea; font-size: 32px; font-weight: 700; letter-spacing: 3px; font-family: monospace;">${inviteCode}</p>
              </div>
              
              <!-- Instructions -->
              <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; margin-bottom: 30px;">
                <h3 style="margin: 0 0 15px; color: #333333; font-size: 16px; font-weight: 600;">How to Join:</h3>
                <ol style="margin: 0; padding-left: 20px; color: #555555; font-size: 14px; line-height: 1.8;">
                  <li>Download the InterBridge app if you haven't already</li>
                  <li>Sign in or create an account</li>
                  <li>Go to Settings → Join Organization</li>
                  <li>Enter the invite code above</li>
                  <li>Start requesting interpretation services!</li>
                </ol>
              </div>
              
              <p style="margin: 0; color: #888888; font-size: 14px; line-height: 1.6;">
                This invitation will expire in 7 days. If you have any questions, please contact your organization administrator.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 30px 40px; background-color: #f8f9fa; border-radius: 0 0 12px 12px; text-align: center;">
              <p style="margin: 0 0 10px; color: #888888; font-size: 12px;">
                This email was sent by InterBridge on behalf of ${organizationName}.
              </p>
              <p style="margin: 0; color: #888888; font-size: 12px;">
                © ${new Date().getFullYear()} InterBridge. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}
