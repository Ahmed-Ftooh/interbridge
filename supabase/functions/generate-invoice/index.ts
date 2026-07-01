// Generate Invoice — creates monthly invoice for an organization
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function resolveLanguageName(languageMap: Map<number, string>, lang: unknown) {
  if (lang == null) return "?";
  if (typeof lang === "number") return languageMap.get(lang) ?? String(lang);
  if (typeof lang === "string") {
    const parsed = Number(lang);
    if (!Number.isNaN(parsed)) {
      return languageMap.get(parsed) ?? lang;
    }
    return lang;
  }
  return String(lang);
}

function truncateText(
  font: { widthOfTextAtSize: (t: string, s: number) => number },
  text: string,
  size: number,
  maxWidth: number
) {
  const safeText = sanitizePdfText(text);
  if (font.widthOfTextAtSize(safeText, size) <= maxWidth) return safeText;
  let trimmed = safeText;
  while (trimmed.length > 1 && font.widthOfTextAtSize(`${trimmed}...`, size) > maxWidth) {
    trimmed = trimmed.slice(0, -1);
  }
  return `${trimmed}...`;
}

function sanitizePdfText(text: string): string {
  return text
    .replaceAll("\u2014", "-")
    .replaceAll("\u2013", "-")
    .replaceAll("\u2192", "->")
    .replaceAll("\u2026", "...");
}

async function generateInvoicePdf(
  org: Record<string, unknown>,
  invoice: Record<string, unknown>,
  lineItems: Array<Record<string, unknown>>,
  languageMap: Map<number, string>
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const pageSize: [number, number] = [595.28, 841.89];

  let page = pdfDoc.addPage(pageSize);
  let y = page.getHeight() - 48;
  const margin = 48;
  const textColor = rgb(0.12, 0.14, 0.18);
  const muted = rgb(0.4, 0.45, 0.5);
  const accent = rgb(0.04, 0.33, 0.98);

  const drawText = (
    text: string,
    size = 12,
    opts: { x?: number; color?: ReturnType<typeof rgb>; bold?: boolean } = {}
  ) => {
    page.drawText(sanitizePdfText(text), {
      x: opts.x ?? margin,
      y,
      size,
      font: opts.bold ? fontBold : font,
      color: opts.color ?? textColor,
    });
    y -= size + 6;
  };

  const drawRight = (
    text: string,
    size: number,
    yPos: number,
    color = textColor,
    bold = false
  ) => {
    const activeFont = bold ? fontBold : font;
    const safeText = sanitizePdfText(text);
    const width = activeFont.widthOfTextAtSize(safeText, size);
    page.drawText(safeText, {
      x: page.getWidth() - margin - width,
      y: yPos,
      size,
      font: activeFont,
      color,
    });
  };

  const invoiceNumber = String(invoice.invoice_number ?? "-");
  const periodStart = formatDate(invoice.billing_period_start as string);
  const periodEnd = formatDate(invoice.billing_period_end as string);
  const dueDate = formatDate(invoice.due_date as string);

  drawText("InterBridge", 20, { bold: true, color: accent });
  drawText("Medical Interpretation Services", 12, { color: muted });

  drawRight(`Invoice #${invoiceNumber}`, 16, page.getHeight() - 56, accent, true);
  drawRight(`Period: ${periodStart} - ${periodEnd}`, 10, page.getHeight() - 74, muted);
  drawRight(`Due: ${dueDate}`, 10, page.getHeight() - 90, muted);

  y -= 14;
  drawText("Bill To", 10, { color: muted, bold: true });
  drawText(String(org.name ?? "Organization"), 14, { bold: true });
  if (org.email) drawText(String(org.email), 11, { color: muted });
  if (org.address) drawText(String(org.address), 11, { color: muted });

  y -= 6;
  const summaryStart = y;
  const summaryItems = [
    { label: "Total Calls", value: String(invoice.total_calls ?? 0) },
    { label: "Total Minutes", value: String(invoice.total_minutes ?? 0) },
    {
      label: "Staff Cost",
      value: `$${(invoice.staff_cost as number | undefined ?? 0).toFixed(2)}`,
    },
    {
      label: "Overflow Cost",
      value: `$${(invoice.overflow_cost as number | undefined ?? 0).toFixed(2)}`,
    },
  ];

  const cardWidth = (page.getWidth() - margin * 2 - 24) / 4;
  summaryItems.forEach((item, index) => {
    const cardX = margin + index * (cardWidth + 8);
    page.drawRectangle({
      x: cardX,
      y: summaryStart - 50,
      width: cardWidth,
      height: 48,
      color: rgb(0.97, 0.98, 0.99),
      borderColor: rgb(0.89, 0.91, 0.94),
      borderWidth: 1,
    });
    page.drawText(item.value, {
      x: cardX + 10,
      y: summaryStart - 24,
      size: 12,
      font: fontBold,
      color: accent,
    });
    page.drawText(item.label, {
      x: cardX + 10,
      y: summaryStart - 38,
      size: 8,
      font,
      color: muted,
    });
  });

  y = summaryStart - 70;

  const headerColor = rgb(0.38, 0.44, 0.5);
  const tableX = margin;
  const colDate = tableX;
  const colDoctor = tableX + 80;
  const colLang = tableX + 220;
  const colDuration = tableX + 410;
  const colCost = tableX + 480;

  const drawTableHeader = () => {
    page.drawText("Date", { x: colDate, y, size: 9, font: fontBold, color: headerColor });
    page.drawText("Doctor", { x: colDoctor, y, size: 9, font: fontBold, color: headerColor });
    page.drawText("Languages", { x: colLang, y, size: 9, font: fontBold, color: headerColor });
    page.drawText("Duration", { x: colDuration, y, size: 9, font: fontBold, color: headerColor });
    page.drawText("Cost", { x: colCost, y, size: 9, font: fontBold, color: headerColor });
    y -= 14;
  };

  drawTableHeader();

  for (const item of lineItems) {
    if (y < 100) {
      page = pdfDoc.addPage(pageSize);
      y = page.getHeight() - 48;
      drawTableHeader();
    }
    const date = formatDate(item.date as string);
    const doctor = String(item.doctor ?? "Doctor");
    const from = resolveLanguageName(languageMap, item.from_language);
    const to = resolveLanguageName(languageMap, item.to_language);
    const mins = String(item.duration_minutes ?? 0);
    const cost = `$${((item.cost as number) ?? 0).toFixed(2)}`;
    const overflow = item.overflow ? " (overflow)" : "";

    page.drawText(date, { x: colDate, y, size: 9, font, color: textColor });
    page.drawText(
      truncateText(font, doctor, 9, colLang - colDoctor - 8),
      { x: colDoctor, y, size: 9, font, color: textColor }
    );
    page.drawText(
      truncateText(font, `${from} -> ${to}${overflow}`, 9, colDuration - colLang - 8),
      { x: colLang, y, size: 9, font, color: textColor }
    );
    page.drawText(`${mins} min`, { x: colDuration, y, size: 9, font, color: textColor });
    page.drawText(cost, { x: colCost, y, size: 9, font, color: textColor });
    y -= 12;
  }

  y -= 12;
  const totalAmount = `$${(invoice.total_amount as number | undefined ?? 0).toFixed(2)}`;
  page.drawText("Total", { x: colDuration, y, size: 11, font: fontBold, color: accent });
  page.drawText(totalAmount, { x: colCost, y, size: 11, font: fontBold, color: accent });

  return pdfDoc.save();
}

function generateInvoiceHtml(
  org: Record<string, unknown>,
  invoice: Record<string, unknown>,
  lineItems: Array<Record<string, unknown>>,
  languageMap: Map<number, string>
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

  const resolveLanguageName = (lang: unknown): string => {
    if (lang == null) return "?";
    if (typeof lang === "number") return languageMap.get(lang) ?? String(lang);
    if (typeof lang === "string") {
      const parsed = Number(lang);
      if (!Number.isNaN(parsed)) {
        return languageMap.get(parsed) ?? lang;
      }
      return lang;
    }
    return String(lang);
  };

  const rows = lineItems
    .map((item) => {
      const date = formatDate(item.date as string);
      const doctor = item.doctor ?? "Doctor";
      const from = resolveLanguageName(item.from_language);
      const to = resolveLanguageName(item.to_language);
      const mins = item.duration_minutes ?? 0;
      const cost = ((item.cost as number) ?? 0).toFixed(2);
      const overflow = item.overflow ? " (overflow)" : "";
      return `<tr>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${date}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${doctor}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0">${from} - ${to}${overflow}</td>
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
    .actions { text-align: right; margin: 0 0 16px; }
    .actions button { background: #0955FA; color: #fff; border: none; padding: 8px 14px; border-radius: 6px; cursor: pointer; font-size: 12px; }
    .actions button:hover { background: #0a46c3; }
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

  <div class="actions">
    <button onclick="window.print()">Print / Save PDF</button>
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
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // AUTH: require a valid Supabase JWT
    const authHeader = req.headers.get("authorization") ?? "";
    const callerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!callerToken) return json({ error: "Unauthorized" }, 401);

    const { data: userData, error: userError } = await supabase.auth.getUser(callerToken);
    if (userError || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const callerId = userData.user.id;

    const body = await req.json().catch(() => null);
    if (!body) return json({ error: "Invalid JSON body" }, 400);

    const { organization_id, year, month, send_email } = body;

    if (!organization_id || !year || !month) {
      return json(
        { error: "Missing required fields: organization_id, year, month" },
        400
      );
    }

    // AUTHZ: caller must be org admin or superadmin
    const { data: callerProfile } = await supabase
      .from("users_profile")
      .select("role")
      .eq("user_id", callerId)
      .maybeSingle();

    const isSuperAdmin = callerProfile?.role === "admin" || callerProfile?.role === "superadmin";

    if (!isSuperAdmin) {
      const { data: membership } = await supabase
        .from("organization_members")
        .select("role")
        .eq("user_id", callerId)
        .eq("organization_id", organization_id)
        .eq("is_active", true)
        .maybeSingle();

      if (!membership || membership.role !== "organization_admin") {
        return json({ error: "Forbidden: only org admins can generate invoices" }, 403);
      }
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

    const languageRows = await supabase
      .from("languages")
      .select("id, name");
    const languageMap = new Map<number, string>();
    for (const row of (languageRows.data ?? []) as Array<Record<string, unknown>>) {
      const rawId = row.id;
      const name = row.name;
      const id = typeof rawId === "number" ? rawId : Number(rawId);
      if (!Number.isNaN(id) && name) {
        languageMap.set(id, String(name));
      }
    }

    // Generate PDF invoice
    const lineItems = (invoice.line_items ?? []) as Array<
      Record<string, unknown>
    >;
    const pdfBytes = await generateInvoicePdf(
      org ?? {},
      invoice,
      lineItems,
      languageMap
    );

    // Upload HTML to Supabase Storage
    const fileName = `invoice_${invoice.invoice_number}_${year}_${String(
      month
    ).padStart(2, "0")}.pdf`;
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
      .upload(storagePath, pdfBytes, {
        contentType: "application/pdf",
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
      const adminRows = await supabase
        .from("organization_members")
        .select("user_id")
        .eq("organization_id", organization_id)
        .eq("role", "organization_admin")
        .eq("is_active", true);

      const adminEmails = new Set<string>();
      for (const row of (adminRows.data ?? []) as Array<Record<string, unknown>>) {
        const userId = row.user_id as string | undefined;
        if (!userId) continue;
        try {
          const { data: authUser, error: authError } =
            await supabase.auth.admin.getUserById(userId);
          if (!authError && authUser?.user?.email) {
            adminEmails.add(authUser.user.email);
          }
        } catch (e) {
          console.error("Failed to fetch admin email:", e);
        }
      }

      if (adminEmails.size === 0) {
        const fallbackEmail = org?.billing_email || org?.email;
        if (fallbackEmail) adminEmails.add(String(fallbackEmail));
      }

      for (const email of adminEmails) {
        try {
          await supabase.functions.invoke("send-invoice-email", {
            body: {
              invoice_id: invoiceId,
              to_email: email,
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
