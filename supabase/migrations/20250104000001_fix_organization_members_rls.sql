-- Migration: Fix organization_members RLS for self-registration
-- Date: 2025-01-04
-- Description: Allow users to add themselves as organization members when creating an org

BEGIN;

-- Add policy to allow users to insert themselves as organization members
-- This is needed when creating a new organization where the user becomes the first admin
DROP POLICY IF EXISTS "org_members_self_insert" ON public.organization_members;
CREATE POLICY "org_members_self_insert"
  ON public.organization_members
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid() 
    OR public.is_admin()
  );

-- Also add a policy for doctors joining via invite
-- Allow insert if the user is adding themselves
DROP POLICY IF EXISTS "org_members_self_update" ON public.organization_members;
CREATE POLICY "org_members_self_update"
  ON public.organization_members
  FOR UPDATE
  USING (
    user_id = auth.uid() 
    OR public.is_admin() 
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members 
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  )
  WITH CHECK (
    user_id = auth.uid() 
    OR public.is_admin() 
    OR organization_id IN (
      SELECT organization_id FROM public.organization_members 
      WHERE user_id = auth.uid() AND role = 'organization_admin'
    )
  );

COMMIT;
