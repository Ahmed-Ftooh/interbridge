// Create Stripe Checkout Session for organization wallet top-up
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

    // Verify JWT and get user
    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization header" }, 401);
    }

    // Verify the user with their JWT
    const supabaseAuth = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabaseAuth.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const { organization_id, amount, success_url, cancel_url } = body;

    if (!organization_id || !amount) {
      return json(
        { error: "Missing required fields: organization_id, amount" },
        400
      );
    }

    if (amount < 5 || amount > 10000) {
      return json({ error: "Amount must be between $5 and $10,000" }, 400);
    }

    // Verify user belongs to this organization
    const { data: membership } = await supabaseAuth
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
    const { data: org } = await supabaseAuth
      .from("organizations")
      .select("stripe_customer_id, name, email")
      .eq("id", organization_id)
      .single();

    let stripeCustomerId = org?.stripe_customer_id;

    if (!stripeCustomerId) {
      // Create Stripe customer
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

      // Save customer ID
      await supabaseAuth
        .from("organizations")
        .update({ stripe_customer_id: stripeCustomerId })
        .eq("id", organization_id);
    }

    // Determine URLs
    const baseUrl =
      success_url?.replace(/\/[^/]*$/, "") ??
      Deno.env.get("APP_URL") ??
      supabaseUrl;
    const finalSuccessUrl =
      success_url || `${baseUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`;
    const finalCancelUrl = cancel_url || `${baseUrl}/payment-cancelled`;

    // Create Stripe Checkout Session
    const sessionRes = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          customer: stripeCustomerId,
          mode: "payment",
          "line_items[0][price_data][currency]": "usd",
          "line_items[0][price_data][unit_amount]": String(
            Math.round(amount * 100)
          ),
          "line_items[0][price_data][product_data][name]":
            "InterBridge Wallet Top-Up",
          "line_items[0][price_data][product_data][description]": `$${amount.toFixed(
            2
          )} wallet top-up for ${org?.name ?? "Organization"}`,
          "line_items[0][quantity]": "1",
          success_url: finalSuccessUrl,
          cancel_url: finalCancelUrl,
          "metadata[organization_id]": organization_id,
          "metadata[amount]": String(amount),
          "metadata[user_id]": user.id,
        }),
      }
    );

    const session = await sessionRes.json();
    if (!sessionRes.ok) {
      console.error("Stripe checkout session error:", session);
      return json(
        { error: session.error?.message ?? "Failed to create checkout session" },
        500
      );
    }

    // Record the checkout session locally for webhook reconciliation
    await supabaseAuth.from("stripe_checkout_sessions").insert({
      organization_id,
      stripe_session_id: session.id,
      amount,
      status: "pending",
    });

    return json({
      checkout_url: session.url,
      session_id: session.id,
    });
  } catch (e) {
    console.error("create-checkout-session error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
