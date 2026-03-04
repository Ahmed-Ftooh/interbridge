-- Billing Pipeline: Auto-charge on call end + Invoice system
-- Replaces the broken BEFORE UPDATE trigger with an AFTER INSERT trigger

BEGIN;

-- ============================================================
-- 1. Drop the old broken trigger (fires on UPDATE but rows are INSERTed with ended_at already set)
-- ============================================================
DROP TRIGGER IF EXISTS call_logs_deduct_cost ON public.call_logs;

-- ============================================================
-- 2. Rewrite deduct_call_cost as AFTER INSERT trigger
--    - Computes cost from organization rate
--    - Updates call_logs.cost
--    - Deducts from organization wallet
--    - Creates organization_transactions record
--    - Tracks doctor spending
-- ============================================================
CREATE OR REPLACE FUNCTION public.deduct_call_cost_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_call_cost DECIMAL(10,2);
  v_org_rate DECIMAL(10,2);
  v_overflow_rate DECIMAL(10,2);
  v_is_overflow BOOLEAN;
  v_new_balance DECIMAL(10,2);
  v_minutes INT;
  v_doctor_name TEXT;
  v_from_lang TEXT;
  v_to_lang TEXT;
BEGIN
  -- Only process calls with an organization
  IF NEW.organization_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get organization rates
  SELECT rate_per_minute, overflow_rate_per_minute
  INTO v_org_rate, v_overflow_rate
  FROM public.organizations
  WHERE id = NEW.organization_id;

  IF v_org_rate IS NULL THEN
    v_org_rate := 1.00;
  END IF;

  -- Check if this is an overflow call (org staff was busy, marketplace interpreter used)
  SELECT COALESCE(overflow_from_org, false) INTO v_is_overflow
  FROM public.interpreter_requests
  WHERE id = NEW.request_id::UUID;

  -- Calculate cost: ceil(seconds/60) * rate
  v_minutes := CEIL(COALESCE(NEW.duration_seconds, 0)::NUMERIC / 60);
  IF v_is_overflow AND v_overflow_rate IS NOT NULL THEN
    v_call_cost := v_minutes * v_overflow_rate;
  ELSE
    v_call_cost := v_minutes * v_org_rate;
  END IF;

  -- Update call_logs with computed cost
  UPDATE public.call_logs
  SET cost = v_call_cost
  WHERE id = NEW.id;

  -- Deduct from organization wallet and get new balance
  UPDATE public.organizations
  SET wallet_balance = wallet_balance - v_call_cost,
      updated_at = NOW()
  WHERE id = NEW.organization_id
  RETURNING wallet_balance INTO v_new_balance;

  -- Track doctor spending
  UPDATE public.organization_members
  SET total_spent = COALESCE(total_spent, 0) + v_call_cost
  WHERE user_id = NEW.requester_id
    AND organization_id = NEW.organization_id;

  -- Get context for transaction notes
  SELECT doctor_name INTO v_doctor_name
  FROM public.interpreter_requests
  WHERE id = NEW.request_id::UUID;

  v_from_lang := NEW.metadata->>'from_language';
  v_to_lang := NEW.metadata->>'to_language';

  -- Create transaction record
  INSERT INTO public.organization_transactions (
    organization_id,
    transaction_type,
    amount,
    balance_after,
    call_id,
    doctor_id,
    notes
  ) VALUES (
    NEW.organization_id,
    'call_charge',
    v_call_cost,
    COALESCE(v_new_balance, 0),
    NEW.id,
    NEW.requester_id,
    COALESCE(v_doctor_name, 'Doctor') || ' — ' ||
    COALESCE(v_from_lang, '?') || ' → ' || COALESCE(v_to_lang, '?') ||
    ' (' || v_minutes || ' min' ||
    CASE WHEN v_is_overflow THEN ', overflow' ELSE '' END || ')'
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER call_logs_auto_charge
AFTER INSERT ON public.call_logs
FOR EACH ROW
EXECUTE FUNCTION public.deduct_call_cost_on_insert();

-- ============================================================
-- 3. Invoices table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  invoice_number SERIAL,
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_calls INT NOT NULL DEFAULT 0,
  total_minutes INT NOT NULL DEFAULT 0,
  staff_calls INT NOT NULL DEFAULT 0,
  overflow_calls INT NOT NULL DEFAULT 0,
  staff_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  overflow_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','overdue','cancelled')),
  line_items JSONB NOT NULL DEFAULT '[]'::JSONB,
  pdf_url TEXT,
  sent_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  due_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS invoices_org_idx ON public.invoices(organization_id);
CREATE INDEX IF NOT EXISTS invoices_status_idx ON public.invoices(status);
CREATE INDEX IF NOT EXISTS invoices_period_idx ON public.invoices(billing_period_start, billing_period_end);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Org members can view invoices for their organization
DROP POLICY IF EXISTS "invoices_view" ON public.invoices;
CREATE POLICY "invoices_view" ON public.invoices
  FOR SELECT USING (
    organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid()
    )
  );

-- Only org admins can manage invoices
DROP POLICY IF EXISTS "invoices_manage" ON public.invoices;
CREATE POLICY "invoices_manage" ON public.invoices
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  );

-- ============================================================
-- 4. Add billing_email to organizations (for invoice delivery)
-- ============================================================
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS billing_email TEXT,
  ADD COLUMN IF NOT EXISTS billing_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS billing_method TEXT DEFAULT 'prepaid' CHECK (billing_method IN ('prepaid', 'postpaid'));

-- ============================================================
-- 5. Stripe-related columns
-- ============================================================
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

-- Track Stripe checkout sessions for webhook reconciliation
CREATE TABLE IF NOT EXISTS public.stripe_checkout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  stripe_session_id TEXT NOT NULL UNIQUE,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','expired','failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.stripe_checkout_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stripe_sessions_view" ON public.stripe_checkout_sessions;
CREATE POLICY "stripe_sessions_view" ON public.stripe_checkout_sessions
  FOR SELECT USING (
    organization_id IN (
      SELECT organization_id FROM public.organization_members
      WHERE user_id = auth.uid()
    )
  );

-- ============================================================
-- 6. Generate invoice function (callable from edge function)
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_monthly_invoice(
  p_organization_id UUID,
  p_year INT,
  p_month INT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_id UUID;
  v_period_start DATE;
  v_period_end DATE;
  v_total_amount DECIMAL(12,2) := 0;
  v_total_calls INT := 0;
  v_total_minutes INT := 0;
  v_staff_calls INT := 0;
  v_overflow_calls INT := 0;
  v_staff_cost DECIMAL(12,2) := 0;
  v_overflow_cost DECIMAL(12,2) := 0;
  v_line_items JSONB := '[]'::JSONB;
  v_existing UUID;
BEGIN
  v_period_start := make_date(p_year, p_month, 1);
  v_period_end := (v_period_start + INTERVAL '1 month')::DATE - 1;

  -- Check if invoice already exists for this period
  SELECT id INTO v_existing
  FROM public.invoices
  WHERE organization_id = p_organization_id
    AND billing_period_start = v_period_start
    AND billing_period_end = v_period_end
    AND status != 'cancelled';

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  -- Aggregate call data from organization_transactions
  SELECT
    COUNT(*),
    COALESCE(SUM(t.amount), 0)
  INTO v_total_calls, v_total_amount
  FROM public.organization_transactions t
  WHERE t.organization_id = p_organization_id
    AND t.transaction_type = 'call_charge'
    AND t.created_at >= v_period_start
    AND t.created_at < (v_period_end + 1);

  -- Aggregate from call_logs for detailed breakdown
  SELECT
    COALESCE(SUM(CEIL(cl.duration_seconds::NUMERIC / 60)), 0),
    COUNT(*) FILTER (WHERE NOT COALESCE(ir.overflow_from_org, false)),
    COUNT(*) FILTER (WHERE COALESCE(ir.overflow_from_org, false)),
    COALESCE(SUM(cl.cost) FILTER (WHERE NOT COALESCE(ir.overflow_from_org, false)), 0),
    COALESCE(SUM(cl.cost) FILTER (WHERE COALESCE(ir.overflow_from_org, false)), 0)
  INTO v_total_minutes, v_staff_calls, v_overflow_calls, v_staff_cost, v_overflow_cost
  FROM public.call_logs cl
  LEFT JOIN public.interpreter_requests ir ON ir.id = cl.request_id::UUID
  WHERE cl.organization_id = p_organization_id
    AND cl.started_at >= v_period_start
    AND cl.started_at < (v_period_end + INTERVAL '1 day');

  -- Build line items JSON from individual calls
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'date', cl.started_at,
      'doctor', COALESCE(ir.doctor_name, 'Doctor'),
      'from_language', cl.metadata->>'from_language',
      'to_language', cl.metadata->>'to_language',
      'duration_minutes', CEIL(cl.duration_seconds::NUMERIC / 60),
      'cost', cl.cost,
      'overflow', COALESCE(ir.overflow_from_org, false)
    ) ORDER BY cl.started_at
  ), '[]'::JSONB)
  INTO v_line_items
  FROM public.call_logs cl
  LEFT JOIN public.interpreter_requests ir ON ir.id = cl.request_id::UUID
  WHERE cl.organization_id = p_organization_id
    AND cl.started_at >= v_period_start
    AND cl.started_at < (v_period_end + INTERVAL '1 day');

  -- Don't create empty invoices
  IF v_total_calls = 0 THEN
    RETURN NULL;
  END IF;

  -- Create invoice
  INSERT INTO public.invoices (
    organization_id, billing_period_start, billing_period_end,
    total_amount, total_calls, total_minutes,
    staff_calls, overflow_calls, staff_cost, overflow_cost,
    status, line_items, due_date
  ) VALUES (
    p_organization_id, v_period_start, v_period_end,
    v_total_amount, v_total_calls, v_total_minutes,
    v_staff_calls, v_overflow_calls, v_staff_cost, v_overflow_cost,
    'draft', v_line_items,
    (v_period_end + INTERVAL '30 days')::DATE
  )
  RETURNING id INTO v_invoice_id;

  RETURN v_invoice_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_monthly_invoice TO authenticated;

COMMIT;
