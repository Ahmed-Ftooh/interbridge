// Generate Invoice — creates monthly invoice for an organization
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

function formatDate(d: string | Date): string {
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function generateInvoiceHtml(
  org: Record<string, unknown>,
  invoice: Record<string, unknown>,
  lineItems: Array<Record<string, unknown>>
): string {
  const orgName = org.name as string;
  const orgEmail = org.email as string;
  const orgAddress = org.address as string;
  const invoiceNumber = invoice.invoice_number;
  const periodStart = formatDate(invoice.billing_period_start as string);
  const periodEnd = formatDate(invoice.billing_period_end as string);
  const dueDate = formatDate(invoice.due_date as string);
  const totalAmount = (invoice.total_amount as number).toFixed(2);
  const totalCalls = invoice.total_calls;
  const totalMinutes = invoice.total_minutes;
  const staffCost = (invoice.staff_cost as number).toFixed(2);
  const overflowCost = (invoice.overflow_cost as number).toFixed(2);

  const rows = lineItems
    .map((item) => {
      const date = formatDate(item.date as string);
      const doctor = item.doctor ?? "Doctor";
      const from = item.from_language ?? "?";
      const to = item.to_language ?? "?";
      const mins = item.duration_minutes ?? 0;
      const cost = ((item.cost as number) ?? 0).toFixed(2);
      const overflow = item.overflow ? " (overflow)" : "";
      return `<tr>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${date}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${doctor}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${from} → ${to}${overflow}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;text-align:right">${mins} min</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;text-align:right">$${cost}</td>
      </tr>`;
    })
    .join("\n");

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invoice #${invoiceNumber}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1e293b; margin: 0; padding: 40px; }
    .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 40px; }
    .logo { font-size: 28px; font-weight: 700; color: #0955FA; }
    .invoice-meta { text-align: right; }
    .invoice-meta h2 { margin: 0; color: #0955FA; font-size: 24px; }
    .invoice-meta p { margin: 4px 0; color: #64748b; font-size: 14px; }
    .bill-to { margin-bottom: 32px; }
    .bill-to h3 { margin: 0 0 8px; color: #64748b; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; }
    .bill-to p { margin: 2px 0; }
    .summary { display: flex; gap: 16px; margin-bottom: 32px; }
    .summary-card { flex: 1; background: #f8fafc; border-radius: 8px; padding: 16px; text-align: center; border: 1px solid #e2e8f0; }
    .summary-card .value { font-size: 24px; font-weight: 700; color: #0955FA; }
    .summary-card .label { font-size: 12px; color: #64748b; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 32px; }
    th { background: #f8fafc; padding: 10px 12px; text-align: left; font-size: 13px; font-weight: 600; color: #64748b; border-bottom: 2px solid #e2e8f0; }
    th:nth-child(4), th:nth-child(5) { text-align: right; }
    .totals { width: 320px; margin-left: auto; }
    .totals tr td { padding: 6px 12px; }
    .totals .total-row td { font-weight: 700; font-size: 18px; border-top: 2px solid #0955FA; padding-top: 12px; }
    .footer { margin-top: 48px; padding-top: 24px; border-top: 1px solid #e2e8f0; text-align: center; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="logo">InterBridge</div>
      <p style="color:#64748b;margin:4px 0">Medical Interpretation Services</p>
    </div>
    <div class="invoice-meta">
      <h2>Invoice #${invoiceNumber}</h2>
      <p>Period: ${periodStart} — ${periodEnd}</p>
      <p>Due: ${dueDate}</p>
    </div>
  </div>

  <div class="bill-to">
    <h3>Bill To</h3>
    <p style="font-weight:600;font-size:16px">${orgName}</p>
    ${orgEmail ? `<p>${orgEmail}</p>` : ""}
    ${orgAddress ? `<p>${orgAddress}</p>` : ""}
  </div>

  <div class="summary">
    <div class="summary-card">
      <div class="value">${totalCalls}</div>
      <div class="label">Total Calls</div>
    </div>
    <div class="summary-card">
      <div class="value">${totalMinutes}</div>
      <div class="label">Total Minutes</div>
    </div>
    <div class="summary-card">
      <div class="value">$${staffCost}</div>
      <div class="label">Staff Cost</div>
    </div>
    <div class="summary-card">
      <div class="value">$${overflowCost}</div>
      <div class="label">Overflow Cost</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Doctor</th>
        <th>Languages</th>
        <th>Duration</th>
        <th>Cost</th>
      </tr>
    </thead>
    <tbody>
      ${rows}
    </tbody>
  </table>

  <table class="totals">
    <tr>
      <td style="color:#64748b">Staff Calls (${invoice.staff_calls})</td>
      <td style="text-align:right">$${staffCost}</td>
    </tr>
    <tr>
      <td style="color:#64748b">Overflow Calls (${invoice.overflow_calls})</td>
      <td style="text-align:right">$${overflowCost}</td>
    </tr>
    <tr class="total-row">
      <td>Total</td>
      <td style="text-align:right;color:#0955FA">$${totalAmount}</td>
    </tr>
  </table>

  <div class="footer">
    <p>InterBridge — Medical Interpretation Services</p>
    <p>This invoice was auto-generated. For questions, contact support@interbridge.app</p>
  </div>
</body>
</html>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const { organization_id, year, month, send_email } = body;

    if (!organization_id || !year || !month) {
      return json(
        { error: "Missing required fields: organization_id, year, month" },
        400
      );
    }

    // Call DB function to generate invoice (handles aggregation + idempotency)
    const { data: invoiceId, error: rpcError } = await supabase.rpc(
      "generate_monthly_invoice",
      {
        p_organization_id: organization_id,
        p_year: year,
        p_month: month,
      }
    );

    if (rpcError) {
      console.error("generate_monthly_invoice error:", rpcError);
      return json({ error: rpcError.message }, 500);
    }

    if (!invoiceId) {
      return json({
        status: "no_data",
        message: "No calls found for this billing period",
      });
    }

    // Fetch the invoice with full data
    const { data: invoice, error: fetchError } = await supabase
      .from("invoices")
      .select("*")
      .eq("id", invoiceId)
      .single();

    if (fetchError || !invoice) {
      return json({ error: "Failed to fetch generated invoice" }, 500);
    }

    // Fetch organization data
    const { data: org } = await supabase
      .from("organizations")
      .select("name, email, address, billing_email, billing_contact_name")
      .eq("id", organization_id)
      .single();

    // Generate HTML invoice
    const lineItems = (invoice.line_items ?? []) as Array<
      Record<string, unknown>
    >;
    const html = generateInvoiceHtml(org ?? {}, invoice, lineItems);

    // Upload HTML to Supabase Storage
    const fileName = `invoice_${invoice.invoice_number}_${year}_${String(
      month
    ).padStart(2, "0")}.html`;
    const storagePath = `${organization_id}/${fileName}`;

    // Ensure the invoices bucket exists
    try {
      await supabase.storage.createBucket("invoices", {
        public: false,
        fileSizeLimit: 5242880,
      });
    } catch {
      // Bucket may already exist — that's fine
    }

    const { error: uploadError } = await supabase.storage
      .from("invoices")
      .upload(storagePath, new TextEncoder().encode(html), {
        contentType: "text/html",
        upsert: true,
      });

    if (uploadError) {
      console.error("Upload error:", uploadError);
    }

    // Generate signed URL (valid for 30 days)
    const { data: urlData } = await supabase.storage
      .from("invoices")
      .createSignedUrl(storagePath, 60 * 60 * 24 * 30);

    const pdfUrl = urlData?.signedUrl ?? null;

    // Update invoice with the URL and mark as sent if requested
    const updateData: Record<string, unknown> = {
      pdf_url: pdfUrl,
      updated_at: new Date().toISOString(),
    };

    if (send_email) {
      updateData.status = "sent";
      updateData.sent_at = new Date().toISOString();
    }

    await supabase.from("invoices").update(updateData).eq("id", invoiceId);

    // Send email if requested
    if (send_email) {
      const billingEmail =
        org?.billing_email || org?.email;
      if (billingEmail) {
        try {
          await supabase.functions.invoke("send-invoice-email", {
            body: {
              invoice_id: invoiceId,
              to_email: billingEmail,
              org_name: org?.name ?? "Organization",
              invoice_url: pdfUrl,
              total_amount: invoice.total_amount,
              period: `${formatDate(
                invoice.billing_period_start
              )} — ${formatDate(invoice.billing_period_end)}`,
            },
          });
        } catch (emailErr) {
          console.error("Email send error (non-fatal):", emailErr);
        }
      }
    }

    return json({
      status: "success",
      invoice_id: invoiceId,
      invoice_number: invoice.invoice_number,
      total_amount: invoice.total_amount,
      total_calls: invoice.total_calls,
      total_minutes: invoice.total_minutes,
      pdf_url: pdfUrl,
    });
  } catch (e) {
    console.error("generate-invoice error:", e);
    return json({ error: (e as Error)?.message ?? String(e) }, 500);
  }
});
