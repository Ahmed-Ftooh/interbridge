# Supabase Multi-Tier Rollout Plan

Comprehensive schema/storage plan to support the three-tier interpreter model, shift routing, and B2B hospital billing.

## 1. Profiles & Interpreter Metadata
- **users_profile** (existing)
  - `experience_years` (int, default 0)
  - `interpreter_level` (enum: `beginner`, `junior`, `professional`)
  - `employment_type` (enum: `volunteer`, `paid`)
  - `shift_availability` (jsonb array of shift ids)
  - `voice_sample_url`, `general_certificate_url`, `medical_certificate_url`
  - `medical_test_score` (int), `medical_test_duration_seconds` (int)
  - `volunteer_minutes_accumulated` (int) → unlocks certificate at 1,000 minutes
  - `institution_id` (uuid, nullable) → links doctors to hospitals
  - Add policies so interpreters can only update their own records; admins can update all.

- **interpreter_applications** (new)
  - Tracks onboarding submissions + admin review workflow.
  - Columns: `id`, `user_id`, `status`, `reviewer_id`, timestamps, JSON snapshot of documents/test results for audit.
  - Use RLS: applicants can read their own row; admins full access.

## 2. Shift & Availability
- **interpreter_shift_slots** (new)
  - `id`, `user_id`, `shift_type` (`morning`, `night`, `emergency`), `start_time`, `end_time`, `is_on_call`.
  - Enables future scheduling / “on-call” incentives.
- Maintain derived view `active_shift_interpreters` (materialized) for quick routing.

## 3. Call Routing & Billing Data
- **call_logs** (new)
  - `id`, `request_id`, `interpreter_id`, `requester_id`, `institution_id`, `call_type` (`humanitarian`, `medical`), `started_at`, `ended_at`, `duration_seconds`, `shift_type`, `is_emergency`.
  - Drives volunteer minute tracking and doctor billing exports.

- **volunteer_certificates** (new)
  - `id`, `interpreter_id`, `minutes_awarded`, `issued_at`, `certificate_url`.
  - Trigger issues record when `volunteer_minutes_accumulated >= 1000` (and resets counter for next milestone).

## 4. Institutions & B2B Contracts
- **institutions** (new if absent)
  - `id`, `name`, `subscription_plan` (`basic`, `standard`, `premium`), `included_minutes`, `subscription_status`, `subscription_start`, `subscription_end`, billing contacts, `active_users`.
- **institution_users** (new)
  - `id`, `institution_id`, `user_id`, `role` (`admin`, `doctor`), `invited_by`, `status`.
  - HR can invite doctors; doctors authenticate via standard flow but must have active institution.
- Add Supabase function `activate_institution_subscription(institution_id, duration_days)` to toggle `subscription_status` + `subscription_end`.

## 5. Storage Buckets
- `voice_samples` (public = false): audio uploads; grant signed URLs to admins only.
- `interpreter_certificates`: PDFs/images of certificates.
- `medical_tests`: optional bucket if storing question banks or recorded answers.
- Configure RLS storage policies so interpreters can manage their files, admins have read.

## 6. Medical Quiz Content
- **medical_test_questions** (new)
  - `id`, `prompt`, `options` (jsonb), `correct_option`, `time_limit_seconds`, `category`.
- **medical_test_attempts** (new)
  - `id`, `user_id`, `score`, `duration_seconds`, `passed`, `attempted_at`, `details` (jsonb for answers).

## 7. Automation & Functions
- Edge Function `notify_shift_interpreters` to send FCM call cards (ringing) filtered by level + shift + availability.
- Edge Function `generate_institution_invoice` to aggregate call minutes per institution for a billing period and email PDF invoice.
- Trigger `call_logs_after_insert` updates volunteer minutes and institution usage counters.
- Cron job (Supabase Scheduled Function) nightly to expire `subscription_status` when `subscription_end < now()` and to email admins.

## 8. Analytics Views
- `interpreter_performance_view`: combines call duration, response rate, average rating (future), volunteer minutes.
- `institution_usage_view`: minutes used vs plan, emergency minutes, doctor activity counts.

## 9. Migration Order
1. Add new columns to `users_profile` with safe defaults + backfill existing interpreters (level derived from years).
2. Create new tables (`interpreter_applications`, `call_logs`, `institutions`, etc.) with RLS + indexes.
3. Provision storage buckets and policies.
4. Implement triggers/functions (volunteer certificate, call usage, subscription expiry).
5. Update Supabase client code (Flutter) to read/write new columns and drive the new onboarding BLoC.
6. QA flows: volunteer onboarding, paid onboarding, institution doctor login, call logging.

This plan keeps all critical data inside Supabase, supports the three monetization pillars, and leaves room for admin dashboards + reporting later.
