-- ============================================================
-- Auto-Routing & Pre-Call Intake System
-- ============================================================

-- 1. Organization interpreters table (links interpreters to orgs as staff)
CREATE TABLE IF NOT EXISTS public.organization_interpreters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  interpreter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  priority INT DEFAULT 0, -- higher = preferred
  hourly_rate DECIMAL(10,2) DEFAULT 0.00,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(organization_id, interpreter_id)
);

CREATE INDEX IF NOT EXISTS org_interpreters_org_idx ON public.organization_interpreters(organization_id);
CREATE INDEX IF NOT EXISTS org_interpreters_user_idx ON public.organization_interpreters(interpreter_id);

-- 2. Add routing fields to interpreter_requests
ALTER TABLE public.interpreter_requests
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id),
  ADD COLUMN IF NOT EXISTS doctor_name TEXT,
  ADD COLUMN IF NOT EXISTS patient_id TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS routing_mode TEXT DEFAULT 'broadcast', -- 'broadcast' (legacy), 'auto' (new auto-routing)
  ADD COLUMN IF NOT EXISTS routing_phase TEXT DEFAULT 'pending', -- 'pending','matching','matched','overflow','queued','no_match'
  ADD COLUMN IF NOT EXISTS matched_interpreter_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS queue_position INT,
  ADD COLUMN IF NOT EXISTS estimated_wait_seconds INT,
  ADD COLUMN IF NOT EXISTS overflow_from_org BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS intake_completed_at TIMESTAMPTZ;

-- 3. Routing queue table (for when all interpreters are busy)
CREATE TABLE IF NOT EXISTS public.routing_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES public.interpreter_requests(id) ON DELETE CASCADE,
  organization_id UUID REFERENCES public.organizations(id),
  from_language TEXT NOT NULL,
  to_language TEXT NOT NULL,
  specialization TEXT,
  priority INT DEFAULT 0, -- higher = more urgent
  queued_at TIMESTAMPTZ DEFAULT now(),
  estimated_wait_seconds INT DEFAULT 60,
  status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting','assigned','cancelled','expired')),
  assigned_interpreter_id UUID REFERENCES auth.users(id),
  assigned_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS routing_queue_status_idx ON public.routing_queue(status);
CREATE INDEX IF NOT EXISTS routing_queue_lang_idx ON public.routing_queue(from_language, to_language);

-- 4. Overflow pricing config per organization
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS overflow_enabled BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS overflow_rate_per_minute DECIMAL(10,2) DEFAULT 2.00,
  ADD COLUMN IF NOT EXISTS max_staff_interpreters INT DEFAULT 5;

-- 5. RLS policies
ALTER TABLE public.organization_interpreters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routing_queue ENABLE ROW LEVEL SECURITY;

-- organization_interpreters: org admins manage, interpreters see their own
DROP POLICY IF EXISTS "org_interpreters_view" ON public.organization_interpreters;
CREATE POLICY "org_interpreters_view" ON public.organization_interpreters
  FOR SELECT USING (
    interpreter_id = auth.uid()
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "org_interpreters_manage" ON public.organization_interpreters;
CREATE POLICY "org_interpreters_manage" ON public.organization_interpreters
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public.organization_members 
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  );

-- routing_queue: authenticated users can view/manage their own
DROP POLICY IF EXISTS "routing_queue_access" ON public.routing_queue;
CREATE POLICY "routing_queue_access" ON public.routing_queue
  FOR ALL USING (true) WITH CHECK (true);

-- 6. Function: Get available interpreter count for a language pair
CREATE OR REPLACE FUNCTION public.get_available_interpreter_count(
  p_from_language TEXT,
  p_to_language TEXT,
  p_organization_id UUID DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INT;
BEGIN
  IF p_organization_id IS NOT NULL THEN
    -- Count org staff interpreters who are online and not on a call
    SELECT COUNT(DISTINCT oi.interpreter_id) INTO v_count
    FROM public.organization_interpreters oi
    JOIN public.interpreter_details id ON id.user_id = oi.interpreter_id
    JOIN public.interpreter_languages il1 ON il1.user_id = oi.interpreter_id
    JOIN public.interpreter_languages il2 ON il2.user_id = oi.interpreter_id
    WHERE oi.organization_id = p_organization_id
      AND oi.is_active = true
      AND id.is_online = true
      AND id.current_call_id IS NULL
      AND il1.language_id = p_from_language::INT
      AND il2.language_id = p_to_language::INT
      AND il1.language_id != il2.language_id;
  ELSE
    -- Count all marketplace interpreters who are online and not on a call
    SELECT COUNT(DISTINCT id.user_id) INTO v_count
    FROM public.interpreter_details id
    JOIN public.interpreter_languages il1 ON il1.user_id = id.user_id
    JOIN public.interpreter_languages il2 ON il2.user_id = id.user_id
    WHERE id.is_online = true
      AND id.current_call_id IS NULL
      AND il1.language_id = p_from_language::INT
      AND il2.language_id = p_to_language::INT
      AND il1.language_id != il2.language_id;
  END IF;
  
  RETURN COALESCE(v_count, 0);
END;
$$;

-- 7. Function: Auto-route to best interpreter
CREATE OR REPLACE FUNCTION public.auto_route_interpreter(
  p_request_id UUID,
  p_from_language TEXT,
  p_to_language TEXT,
  p_specialization TEXT DEFAULT NULL,
  p_organization_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_interpreter_id UUID;
  v_interpreter_name TEXT;
  v_phase TEXT;
  v_queue_pos INT;
  v_est_wait INT;
  v_result JSONB;
BEGIN
  -- PHASE 1: If org request, try org staff interpreters first
  IF p_organization_id IS NOT NULL THEN
    SELECT oi.interpreter_id INTO v_interpreter_id
    FROM public.organization_interpreters oi
    JOIN public.interpreter_details id ON id.user_id = oi.interpreter_id
    JOIN public.interpreter_languages il1 ON il1.user_id = oi.interpreter_id
    JOIN public.interpreter_languages il2 ON il2.user_id = oi.interpreter_id
    WHERE oi.organization_id = p_organization_id
      AND oi.is_active = true
      AND id.is_online = true
      AND id.current_call_id IS NULL
      AND il1.language_id = p_from_language::INT
      AND il2.language_id = p_to_language::INT
      AND il1.language_id != il2.language_id
    ORDER BY oi.priority DESC, id.total_minutes DESC
    LIMIT 1;

    IF v_interpreter_id IS NOT NULL THEN
      v_phase := 'matched';
      
      -- Mark interpreter as busy
      UPDATE public.interpreter_details
        SET current_call_id = p_request_id
        WHERE user_id = v_interpreter_id;
      
      -- Update request
      UPDATE public.interpreter_requests
        SET matched_interpreter_id = v_interpreter_id,
            routing_phase = 'matched',
            routing_mode = 'auto'
        WHERE id = p_request_id;

      SELECT COALESCE(up.full_name, up.username, 'Interpreter') INTO v_interpreter_name
        FROM public.users_profile up WHERE up.user_id = v_interpreter_id;

      RETURN jsonb_build_object(
        'status', 'matched',
        'interpreter_id', v_interpreter_id,
        'interpreter_name', v_interpreter_name,
        'overflow', false
      );
    END IF;

    -- PHASE 2: Org overflow to marketplace (if enabled)
    IF (SELECT overflow_enabled FROM public.organizations WHERE id = p_organization_id) THEN
      v_phase := 'overflow';
    ELSE
      v_phase := 'queued';
    END IF;
  END IF;

  -- PHASE 2/3: Try marketplace interpreters (all available)
  IF v_interpreter_id IS NULL THEN
    -- Try specialist match first if specialization provided
    IF p_specialization IS NOT NULL AND p_specialization != '' THEN
      SELECT id.user_id INTO v_interpreter_id
      FROM public.interpreter_details id
      JOIN public.interpreter_languages il1 ON il1.user_id = id.user_id
      JOIN public.interpreter_languages il2 ON il2.user_id = id.user_id
      LEFT JOIN public.interpreter_badges ib ON ib.user_id = id.user_id 
        AND ib.badge = LOWER(REPLACE(p_specialization, '/', '_'))
      WHERE id.is_online = true
        AND id.current_call_id IS NULL
        AND il1.language_id = p_from_language::INT
        AND il2.language_id = p_to_language::INT
        AND il1.language_id != il2.language_id
      ORDER BY 
        CASE WHEN ib.score IS NOT NULL THEN 0 ELSE 1 END, -- badged first
        COALESCE(ib.score, 0) DESC,
        id.total_minutes DESC
      LIMIT 1;
    ELSE
      -- General match: best available by experience
      SELECT id.user_id INTO v_interpreter_id
      FROM public.interpreter_details id
      JOIN public.interpreter_languages il1 ON il1.user_id = id.user_id
      JOIN public.interpreter_languages il2 ON il2.user_id = id.user_id
      WHERE id.is_online = true
        AND id.current_call_id IS NULL
        AND il1.language_id = p_from_language::INT
        AND il2.language_id = p_to_language::INT
        AND il1.language_id != il2.language_id
      ORDER BY id.total_minutes DESC
      LIMIT 1;
    END IF;

    IF v_interpreter_id IS NOT NULL THEN
      -- Mark interpreter as busy
      UPDATE public.interpreter_details
        SET current_call_id = p_request_id
        WHERE user_id = v_interpreter_id;
      
      -- Update request
      UPDATE public.interpreter_requests
        SET matched_interpreter_id = v_interpreter_id,
            routing_phase = COALESCE(v_phase, 'matched'),
            routing_mode = 'auto',
            overflow_from_org = (v_phase = 'overflow')
        WHERE id = p_request_id;

      SELECT COALESCE(up.full_name, up.username, 'Interpreter') INTO v_interpreter_name
        FROM public.users_profile up WHERE up.user_id = v_interpreter_id;

      RETURN jsonb_build_object(
        'status', COALESCE(v_phase, 'matched'),
        'interpreter_id', v_interpreter_id,
        'interpreter_name', v_interpreter_name,
        'overflow', (v_phase = 'overflow')
      );
    END IF;
  END IF;

  -- PHASE 4: No interpreter available — queue the request
  SELECT COUNT(*) + 1 INTO v_queue_pos
    FROM public.routing_queue
    WHERE status = 'waiting'
      AND from_language = p_from_language
      AND to_language = p_to_language;

  v_est_wait := v_queue_pos * 60; -- rough estimate: 60s per position

  INSERT INTO public.routing_queue (request_id, organization_id, from_language, to_language, specialization, estimated_wait_seconds)
  VALUES (p_request_id, p_organization_id, p_from_language, p_to_language, p_specialization, v_est_wait);

  UPDATE public.interpreter_requests
    SET routing_phase = 'queued',
        routing_mode = 'auto',
        queue_position = v_queue_pos,
        estimated_wait_seconds = v_est_wait
    WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'status', 'queued',
    'queue_position', v_queue_pos,
    'estimated_wait_seconds', v_est_wait
  );
END;
$$;

-- 8. Function: Release interpreter after call ends (clear current_call_id)
CREATE OR REPLACE FUNCTION public.release_interpreter_after_call()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- When a request is completed/cancelled, release the interpreter
  IF NEW.status IN ('completed', 'cancelled') AND OLD.status NOT IN ('completed', 'cancelled') THEN
    -- Release matched interpreter
    IF NEW.matched_interpreter_id IS NOT NULL THEN
      UPDATE public.interpreter_details
        SET current_call_id = NULL
        WHERE user_id = NEW.matched_interpreter_id
          AND current_call_id = NEW.id;
    END IF;
    -- Release accepted interpreter (legacy flow)
    IF NEW.accepted_by IS NOT NULL THEN
      UPDATE public.interpreter_details
        SET current_call_id = NULL
        WHERE user_id = NEW.accepted_by
          AND current_call_id = NEW.id;
    END IF;
    -- Remove from routing queue if queued
    UPDATE public.routing_queue
      SET status = 'cancelled'
      WHERE request_id = NEW.id AND status = 'waiting';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_release_interpreter ON public.interpreter_requests;
CREATE TRIGGER trigger_release_interpreter
  AFTER UPDATE ON public.interpreter_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.release_interpreter_after_call();

-- 9. Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.auto_route_interpreter TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_interpreter_count TO authenticated;
