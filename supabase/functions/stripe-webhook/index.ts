// Stripe Webhook — handles checkout.session.completed to credit org wallet
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type, stripe-signature",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

// Simple HMAC-SHA256 for Stripe signature verification
async function computeHmac(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload)
  );
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

async function verifyStripeSignature(
  payload: string,
  sigHeader: string,
  secret: string
): Promise<boolean> {
  try {
    const parts = sigHeader.split(",");
    let timestamp = "";
    const signatures: string[] = [];

    for (const part of parts) {
      const [key, value] = part.split("=");
      if (key === "t") timestamp = value;
      if (key === "v1") signatures.push(value);
    }

    if (!timestamp || signatures.length === 0) return false;

    // Check timestamp (within 5 minutes)
    const ts = parseInt(timestamp);
    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - ts) > 300) return false;

    const signedPayload = `${timestamp}.${payload}`;
    const expectedSig = await computeHmac(secret, signedPayload);

    return signatures.some((sig) => timingSafeEqual(sig, expectedSig));
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
    const rawBody = await req.text();

    // Verify signature if webhook secret is set
    if (stripeWebhookSecret) {
      const sigHeader = req.headers.get("stripe-signature") ?? "";
      const valid = await verifyStripeSignature(
        rawBody,
        sigHeader,
        stripeWebhookSecret
      );
      if (!valid) {
        console.error("Invalid Stripe signature");
        return json({ error: "Invalid signature" }, 400);
      }
    }

    const event = JSON.parse(rawBody);
    console.log(`Stripe event: ${event.type} (${event.id})`);

    // Handle both checkout.session.completed and payment_intent.succeeded
    const supportedEvents = [
      "checkout.session.completed",
      "payment_intent.succeeded",
    ];
    if (!supportedEvents.includes(event.type)) {
      // Acknowledge but ignore other event types
      return json({ received: true });
    }

    const session = event.data.object;
    const organizationId = session.metadata?.organization_id;
    // For checkout.session the amount is in metadata;
    // for payment_intent it can also be derived from amount_received (in cents)
    const amount =
      parseFloat(session.metadata?.amount ?? "0") ||
      (session.amount_received ? session.amount_received / 100 : 0);
    // session.id is cs_xxx for checkout or pi_xxx for payment_intent
    const sessionId = session.id;

    if (!organizationId || !amount) {
      console.error("Missing metadata in checkout session:", session.metadata);
      return json({ error: "Missing metadata" }, 400);
    }

    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Check for duplicate processing
    const { data: existingSession } = await supabase
      .from("stripe_checkout_sessions")
      .select("status")
      .eq("stripe_session_id", sessionId)
      .maybeSingle();

    if (existingSession?.status === "completed") {
      console.log("Session already processed:", sessionId);
      return json({ received: true, duplicate: true });
    }

    // Get current wallet balance
    const { data: org, error: orgError } = await supabase
      .from("organizations")
      .select("wallet_balance, name")
      .eq("id", organizationId)
      .single();

    if (orgError || !org) {
      console.error("Organization not found:", organizationId);
      return json({ error: "Organization not found" }, 404);
    }

    const newBalance =
      parseFloat(org.wallet_balance ?? "0") + amount;

    // Create transaction record (the trg_update_org_wallet_balance trigger
    // will auto-update organizations.wallet_balance)
    const { error: txError } = await supabase
      .from("organization_transactions")
      .insert({
        organization_id: organizationId,
        transaction_type: "topup",
        amount: amount,
        balance_after: newBalance,
        payment_reference: `stripe:${sessionId}`,
        notes: `Stripe top-up — $${amount.toFixed(2)}`,
      });

    if (txError) {
      console.error("Transaction insert error:", txError);
      return json({ error: "Failed to record transaction" }, 500);
    }

    // Mark checkout session as completed
    await supabase
      .from("stripe_checkout_sessions")
      .update({ status: "completed", completed_at: new Date().toISOString() })
      .eq("stripe_session_id", sessionId);

    console.log(
      `Wallet topped up: org=${organizationId}, amount=$${amount}, new_balance=$${newBalance}`
    );

    return json({ received: true, success: true });
  } catch (e) {
    console.error("stripe-webhook error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
