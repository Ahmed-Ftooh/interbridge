-- Add storage paths for private buckets
alter table public.voice_samples add column if not exists storage_path text;
alter table public.government_ids add column if not exists storage_path text;

-- Backfill storage_path from existing storage URLs when possible
update public.voice_samples
set storage_path = regexp_replace(
  url,
  '^.*?/object/(?:public|sign)/voice_samples/(.*?)(\\?.*)?$',
  '\\1'
)
where storage_path is null
  and url ~ '/object/(public|sign)/voice_samples/';

update public.government_ids
set storage_path = regexp_replace(
  file_url,
  '^.*?/object/(?:public|sign)/government-ids/(.*?)(\\?.*)?$',
  '\\1'
)
where storage_path is null
  and file_url ~ '/object/(public|sign)/government-ids/';
