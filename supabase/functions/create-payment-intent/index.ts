// Create Stripe PaymentIntent for mobile Payment Sheet (wallet top-up)
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

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization header" }, 401);
    }

    // Verify the user with their JWT
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
const { organization_id, amount, minutes } = body;

    if (!organization_id || !amount) {
      return json({ error: "Missing required fields: organization_id, amount" }, 400);
    }

    if (amount < 5 || amount > 10000) {
      return json({ error: "Amount must be between $5 and $10,000" }, 400);
    }

    // Verify user belongs to this organization
    const { data: membership } = await supabase
      .from("organization_members")
      .select("role")
      .eq("user_id", user.id)
      .eq("organization_id", organization_id)
      .eq("is_active", true)
      .maybeSingle();

    if (!membership) {
      return json({ error: "Not a member of this organization" }, 403);
    }

    // Get or create Stripe customer
    const { data: org } = await supabase
      .from("organizations")
      .select("stripe_customer_id, name, email")
      .eq("id", organization_id)
      .single();

    let stripeCustomerId = org?.stripe_customer_id;

    if (!stripeCustomerId) {
      const customerRes = await fetch(
        "https://api.stripe.com/v1/customers",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${stripeSecretKey}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            name: org?.name ?? "Organization",
            ...(org?.email ? { email: org.email } : {}),
            "metadata[organization_id]": organization_id,
            "metadata[source]": "interbridge",
          }),
        }
      );

      const customer = await customerRes.json();
      if (!customerRes.ok) {
        console.error("Stripe customer creation error:", customer);
        return json({ error: "Failed to create Stripe customer" }, 500);
      }

      stripeCustomerId = customer.id;

      await supabase
        .from("organizations")
        .update({ stripe_customer_id: stripeCustomerId })
        .eq("id", organization_id);
    }

    // Create an ephemeral key for the customer
    const ephemeralKeyRes = await fetch(
      "https://api.stripe.com/v1/ephemeral_keys",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
          "Stripe-Version": "2024-06-20",
        },
        body: new URLSearchParams({
          customer: stripeCustomerId,
        }),
      }
    );

    const ephemeralKey = await ephemeralKeyRes.json();
    if (!ephemeralKeyRes.ok) {
      console.error("Ephemeral key error:", ephemeralKey);
      return json({ error: "Failed to create ephemeral key" }, 500);
    }

    // Create a PaymentIntent
    const paymentIntentRes = await fetch(
      "https://api.stripe.com/v1/payment_intents",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          amount: String(Math.round(amount * 100)),
          currency: "usd",
          customer: stripeCustomerId,
          "automatic_payment_methods[enabled]": "true",
          "metadata[organization_id]": organization_id,
          "metadata[amount]": String(amount),
          "metadata[user_id]": user.id,
          "metadata[source]": "mobile_payment_sheet",
          // ADD THIS LINE TO ATTACH MINUTES IF IT'S A SUBSCRIPTION:
          ...(minutes ? { "metadata[minutes]": String(minutes) } : {}),
          
          // Make the Stripe receipt look correct:
          description: minutes 
            ? `Subscription Plan: ${minutes} minutes` 
            : `$${Number(amount).toFixed(2)} wallet top-up for ${org?.name ?? "Organization"}`,
        }),
      }
    );
    const paymentIntent = await paymentIntentRes.json();
    if (!paymentIntentRes.ok) {
      console.error("PaymentIntent error:", paymentIntent);
      return json(
        {
          error:
            paymentIntent.error?.message ?? "Failed to create payment intent",
        },
        500
      );
    }

    // Record the session locally for webhook reconciliation
    await supabase.from("stripe_checkout_sessions").insert({
      organization_id,
      stripe_session_id: paymentIntent.id,
      amount,
      status: "pending",
    });

    return json({
      payment_intent: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      ephemeral_key: ephemeralKey.secret,
      customer: stripeCustomerId,
      publishable_key: Deno.env.get("STRIPE_PUBLISHABLE_KEY") ?? "",
    });
  } catch (e) {
    console.error("create-payment-intent error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
