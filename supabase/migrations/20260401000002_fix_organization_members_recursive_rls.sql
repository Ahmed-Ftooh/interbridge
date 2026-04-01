-- Fix recursive RLS policy on organization_members that caused PostgREST 500 errors
-- Error observed: infinite recursion detected in policy for relation "organization_members"

BEGIN;

-- Legacy policy recreated in a performance migration and is recursively self-referential.
DROP POLICY IF EXISTS "org_members_self_view" ON public.organization_members;

COMMIT;
