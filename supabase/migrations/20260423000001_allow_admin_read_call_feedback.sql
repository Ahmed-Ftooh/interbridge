drop policy if exists call_feedback_select on public.call_feedback;

create policy call_feedback_select
on public.call_feedback
for select
to public
using (
  ((select auth.uid()) = user_id)
  or public.is_admin()
);
