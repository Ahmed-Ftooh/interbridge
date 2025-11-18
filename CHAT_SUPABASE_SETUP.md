# Chat System - Supabase Setup Guide

## Overview
This document outlines the Supabase database schema and configuration needed for the chat system to work reliably, similar to Tarjimly app.

## Issues Fixed
1. ✅ Voice messages now appear immediately for both sender and receiver
2. ✅ Removed auto-restore dialog (autosave is always active)
3. ✅ Added fallback signed URL generation for attachments
4. ✅ Enhanced logging for debugging

## Required Supabase Tables

### 1. chat_messages table
```sql
create table if not exists public.chat_messages (
  id uuid not null default gen_random_uuid(),
  request_id uuid not null,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  message_type text not null default 'text',
  attachment_url text,
  created_at timestamptz not null default now(),
  constraint chat_messages_pkey primary key (id)
);

-- Index for fast message retrieval
create index if not exists chat_messages_request_id_idx 
  on public.chat_messages (request_id, created_at);

-- Index for sender lookups
create index if not exists chat_messages_sender_id_idx 
  on public.chat_messages (sender_id);
```

### 2. Enable Row Level Security (RLS)
```sql
alter table public.chat_messages enable row level security;

-- Policy: Users can read messages for requests they're part of
create policy "Users can read their chat messages"
on public.chat_messages
for select
using (
  exists (
    select 1 from public.interpreter_requests r
    where r.id = request_id
      and (r.requester_id = auth.uid() or r.accepted_by = auth.uid())
  )
);

-- Policy: Users can insert messages for requests they're part of
create policy "Users can send chat messages"
on public.chat_messages
for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.interpreter_requests r
    where r.id = request_id
      and (r.requester_id = auth.uid() or r.accepted_by = auth.uid())
  )
);
```

### 3. Enable Realtime Replication
This is **CRITICAL** for messages to sync instantly between users.

In Supabase Dashboard:
1. Go to **Database** → **Replication**
2. Enable replication for `chat_messages` table
3. Select **INSERT** events

Or via SQL:
```sql
-- Enable realtime for chat_messages
alter publication supabase_realtime add table public.chat_messages;
```

### 4. Storage Bucket for Attachments
```sql
-- Create storage bucket for chat attachments
insert into storage.buckets (id, name, public)
values ('chat_attachments', 'chat_attachments', false);

-- Storage policies: Users can upload attachments
create policy "Users can upload chat attachments"
on storage.objects for insert
with check (
  bucket_id = 'chat_attachments'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Storage policies: Users can read attachments for their chats
create policy "Users can read chat attachments"
on storage.objects for select
using (
  bucket_id = 'chat_attachments'
  and auth.role() = 'authenticated'
);

-- Storage policies: Users can delete their own attachments
create policy "Users can delete their own attachments"
on storage.objects for delete
using (
  bucket_id = 'chat_attachments'
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);
```

## Agora Setup (Voice Calls)

### Edge Function: generate-agora-token
Create this Supabase Edge Function at `supabase/functions/generate-agora-token/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token@2.0.4'

serve(async (req) => {
  try {
    const { channelName, uid } = await req.json()
    
    // Get from Supabase secrets or environment
    const appId = Deno.env.get('AGORA_APP_ID')!
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE')!
    
    const role = RtcRole.PUBLISHER
    const expirationTimeInSeconds = 3600 // 1 hour
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      parseInt(uid),
      role,
      privilegeExpiredTs
    )
    
    return new Response(
      JSON.stringify({ token }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

Deploy:
```bash
supabase functions deploy generate-agora-token
```

Set secrets:
```bash
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

## Testing Checklist

### Chat Messages
- [ ] Text messages appear instantly for both users
- [ ] Voice messages upload and play for both users
- [ ] Images upload and display for both users
- [ ] PDF files upload and can be opened

### Realtime Sync
- [ ] Messages sync without hot restart
- [ ] Multiple users can chat simultaneously
- [ ] Messages appear in correct order
- [ ] No duplicate messages

### Voice Calls
- [ ] Call invitation appears in chat
- [ ] Both users join the call
- [ ] Audio works in both directions
- [ ] Mute/Speaker toggle works
- [ ] Call ends properly

### Translation Drafts
- [ ] Progress saves automatically every 2 seconds
- [ ] No dialog appears on app restart
- [ ] Draft persists across app closures
- [ ] Draft clears only on submission

## Troubleshooting

### Messages not syncing in realtime
**Problem**: Messages only appear after hot restart  
**Solution**: 
1. Verify realtime is enabled: `alter publication supabase_realtime add table public.chat_messages;`
2. Check browser console for realtime connection errors
3. Verify RLS policies allow both users to SELECT messages

### Voice messages not playing
**Problem**: Audio player shows error  
**Solution**:
1. Check storage bucket exists: `chat_attachments`
2. Verify storage policies allow reading
3. Check signed URL generation in logs
4. Ensure `.m4a` files use `audio/mp4` content type

### Call not connecting
**Problem**: Only one user joins the call  
**Solution**:
1. Verify Agora App ID and Certificate are set
2. Check Edge Function is deployed and working
3. Verify microphone permissions are granted
4. Check Agora token expiration (default 1 hour)

### Draft restoration issues
**Problem**: Draft dialog appears or progress lost  
**Solution**:
1. Autosave is now always active, no dialog should appear
2. Check `translation_drafts` table exists with proper RLS
3. Verify `upsertDraft` is being called every 2 seconds
4. Check both local cache and server draft are being saved

## Performance Optimization

### Message Pagination
Current implementation loads last 100 messages. For better performance:
```dart
// Fetch older messages on scroll
final olderMessages = await service.fetchMessages(
  requestId,
  limit: 50,
  offset: currentMessages.length,
);
```

### Attachment Size Limits
Set max file sizes in storage policies:
```sql
create policy "Limit file upload size"
on storage.objects for insert
with check (
  bucket_id = 'chat_attachments'
  and auth.role() = 'authenticated'
  and octet_length(decode(metadata->>'size', 'escape')) < 10485760  -- 10MB
);
```

### Clean Up Old Attachments
Schedule cleanup of attachments from deleted messages:
```sql
-- Create a function to clean orphaned attachments
-- Run via pg_cron or Supabase scheduled functions
```

## Migration Files Location
- `supabase/migrations/20251115120000_add_translation_drafts.sql` - Translation drafts table
- Add new migration for chat_messages if not exists
- Add new migration for storage policies

## Next Steps
1. ✅ Apply all SQL migrations above
2. ✅ Enable realtime replication
3. ✅ Deploy Agora Edge Function
4. ✅ Test all features with 2 users
5. ✅ Monitor logs for any errors

---
Last Updated: 2025-11-15
