-- Enable pg_net and pg_cron extensions if they are not already enabled
create extension if not exists pg_net;
create extension if not exists pg_cron;

-- Schedule the monthly invoice generation for the 1st of the month at 02:00 AM UTC.
-- This securely calls the edge function from inside your database using pg_net.

-- IMPORTANT: Before running this in production, replace the placeholders with your actual secrets.
-- URL: Your Supabase Project API URL (e.g., https://<YOUR_REF>.supabase.co/functions/v1/auto-generate-invoices)
-- Authorization: Your service_role key or anon key (service_role is recommended for internal cron jobs)
-- x-cron-secret: The custom secret we just added to the Edge Function to prevent public exploitation

select cron.schedule(
    'monthly-invoices',
    '0 2 1 * *', -- 1st of the month at 02:00 AM
    $$
    select net.http_post(
        url := 'https://gwvxwaqicnwiplafayoh.supabase.co/functions/v1/auto-generate-invoices',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3dnh3YXFpY253aXBsYWZheW9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMwMzg4MTIsImV4cCI6MjA2ODYxNDgxMn0.11o3K-47QMg7y8ksTrifn7C-trVGgdkYP0wnFv6ONEw", "x-cron-secret": "aB9#vL2!mP8@xW5%yK4"}'::jsonb,
        timeout_milliseconds := 300000 -- 5 minute timeout since PDF generation and emails might take a while
    );
    $$
);
