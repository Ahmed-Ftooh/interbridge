// Confirm mobile payment — called after Stripe PaymentSheet succeeds.
// Verifies the PaymentIntent status with Stripe, then credits the wallet.
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
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      return json({ error: "Stripe not configured" }, 500);
    }

    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    // Authenticate the caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization header" }, 401);
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const { payment_intent_id } = body;
    if (!payment_intent_id) {
      return json({ error: "Missing payment_intent_id" }, 400);
    }

    // ─── Verify the PaymentIntent with Stripe ────────────────────────
    const piRes = await fetch(
      `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(
        payment_intent_id
      )}`,
      {
        headers: { Authorization: `Bearer ${stripeSecretKey}` },
      }
    );

    const pi = await piRes.json();
    if (!piRes.ok || !pi.id) {
      console.error("Stripe PI fetch failed:", pi);
      return json({ error: "Failed to verify payment with Stripe" }, 500);
    }

    if (pi.status !== "succeeded") {
      return json(
        { error: `Payment not completed (status: ${pi.status})` },
        400
      );
    }
// Extract metadata
    const organizationId = pi.metadata?.organization_id;
    const amount =
      parseFloat(pi.metadata?.amount ?? "0") ||
      (pi.amount_received ? pi.amount_received / 100 : 0);
    
    // Check if this was a subscription purchase!
    const minutes = pi.metadata?.minutes ? parseInt(pi.metadata.minutes) : null;

    if (!organizationId || !amount) {
      return json({ error: "Missing metadata on PaymentIntent" }, 400);
    }

    // ... (Keep the membership and deduplication checks the same) ...

    // ─── Credit the Organization ───────────────────────────────────────────
    const { data: org, error: orgError } = await supabase
      .from("organizations")
      .select("wallet_balance")
      .eq("id", organizationId)
      .single();

    if (orgError || !org) {
      return json({ error: "Organization not found" }, 404);
    }

    // NEW LOGIC: Branch based on payment type
    if (minutes) {
      // IT IS A SUBSCRIPTION: Update plan limits instead of wallet
      
      // 1. Update the organization's subscription data
      await supabase
        .from("organizations")
        .update({ 
          subscription_monthly_minutes: minutes,
          subscription_minutes_used: 0 // Reset usage since they bought a new plan
        })
        .eq("id", organizationId);

      // 2. Log the transaction for receipt history
      await supabase.from("organization_transactions").insert({
        organization_id: organizationId,
        transaction_type: "subscription_purchase",
        amount: amount,
        balance_after: parseFloat(org.wallet_balance ?? "0"), // Wallet is unaffected
        payment_reference: `stripe:${pi.id}`,
        notes: `Purchased ${minutes} Minute Monthly Plan`,
      });

      console.log(`Subscription confirmed: org=${organizationId}, minutes=${minutes}`);

    } else {
      // IT IS A PREPAID TOP-UP: Keep your exact original logic
      const newBalance = parseFloat(org.wallet_balance ?? "0") + amount;

      const { error: txError } = await supabase
        .from("organization_transactions")
        .insert({
          organization_id: organizationId,
          transaction_type: "topup",
          amount: amount,
          balance_after: newBalance,
          payment_reference: `stripe:${pi.id}`,
          notes: `Mobile top-up — $${amount.toFixed(2)}`,
        });

      if (txError) {
        console.error("Transaction insert error:", txError);
        return json({ error: "Failed to record transaction" }, 500);
      }
      console.log(`Mobile payment confirmed: org=${organizationId}, amount=$${amount}, new_balance=$${newBalance}`);
    }

    // Mark the checkout session as completed
    await supabase
      .from("stripe_checkout_sessions")
      .update({ status: "completed", completed_at: new Date().toISOString() })
      .eq("stripe_session_id", pi.id);

    return json({
      success: true,
      amount: amount,
    });
  }});