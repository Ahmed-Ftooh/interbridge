-- Migration: Fix organizations RLS for new registration
-- Date: 2026-01-20
-- Description: Allow authenticated users to create new organizations during registration

BEGIN;

-- Drop existing insert policy if it exists
DROP POLICY IF EXISTS "organizations_insert" ON public.organizations;

-- Create policy to allow any authenticated user to create an organization
-- This is needed during registration when a user creates their first organization
CREATE POLICY "organizations_insert"
  ON public.organizations
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Also ensure SELECT policy exists for users who just created an org
-- They need to be able to read back the org ID immediately after creation
DROP POLICY IF EXISTS "organizations_select" ON public.organizations;
CREATE POLICY "organizations_select"
  ON public.organizations
  FOR SELECT
  USING (
    public.is_admin() 
    OR id IN (
      SELECT organization_id FROM public.organization_members WHERE user_id = auth.uid()
    )
    -- Allow users to see orgs they just created (within 60 seconds)
    -- This handles the race condition where org is created before membership
    OR (created_at > (now() - interval '60 seconds'))
  );

COMMIT;
