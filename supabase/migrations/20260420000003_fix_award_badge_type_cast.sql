-- Fix badge save failure: function had search_path='' with unqualified badge_type casts.
-- With empty search_path, Postgres cannot resolve badge_type unless schema-qualified.

CREATE OR REPLACE FUNCTION public.award_badge_on_quiz_pass()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.quiz_type = 'medical' AND NEW.passed = true AND NEW.medical_section IS NOT NULL THEN
    INSERT INTO public.interpreter_badges(user_id, badge, score)
    VALUES (
      NEW.user_id,
      (NEW.medical_section::text)::public.badge_type,
      NEW.score_percentage::integer
    )
    ON CONFLICT (user_id, badge) DO UPDATE
      SET score = GREATEST(public.interpreter_badges.score, EXCLUDED.score),
          earned_at = now();
  END IF;

  IF NEW.quiz_type = 'general' AND NEW.passed = true THEN
    INSERT INTO public.interpreter_badges(user_id, badge, score)
    VALUES (
      NEW.user_id,
      'general'::public.badge_type,
      NEW.score_percentage::integer
    )
    ON CONFLICT (user_id, badge) DO UPDATE
      SET score = GREATEST(public.interpreter_badges.score, EXCLUDED.score),
          earned_at = now();
  END IF;

  RETURN NEW;
END;
$function$;
