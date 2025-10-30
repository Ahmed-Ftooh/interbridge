# Database Migration Setup Instructions

## Problem
You're seeing these errors because the `document_translation_requests` table doesn't exist in your Supabase database yet:

```
Error creating document translation request: PostgrestException(message: Could not find the 'file_name' column of 'document_translation_requests' in the schema cache
```

## Solution

You need to apply the migration file to create the table. Follow these steps:

### Option 1: Using Supabase CLI (Recommended)

1. Make sure you have Supabase CLI installed:
   ```bash
   npm install -g supabase
   ```

2. Link your project (if not already linked):
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

3. Push the migration to your database:
   ```bash
   supabase db push
   ```

### Option 2: Using Supabase Dashboard (Easiest)

**IMPORTANT**: You need to run TWO migration files:

#### Step 1: Create and Seed Languages Table

1. Go to your Supabase Dashboard: https://supabase.com/dashboard

2. Navigate to your project

3. Click on "SQL Editor" in the left sidebar

4. Click "New Query"

5. Open the migration file: `supabase/migrations/create_and_seed_languages_table.sql`

6. Copy the entire contents of that file

7. Paste it into the SQL Editor

8. Click "Run" or press Ctrl+Enter (Cmd+Enter on Mac)

9. You should see a success message with "122 rows affected" or similar

#### Step 2: Create Document Translation Requests Table

1. Still in the SQL Editor, click "New Query" again

2. Open the migration file: `supabase/migrations/create_document_translation_requests_table.sql`

3. Copy the entire contents of that file

4. Paste it into the SQL Editor

5. Click "Run" or press Ctrl+Enter (Cmd+Enter on Mac)

6. You should see a success message like "Success. No rows returned"

#### Step 3: Add Missing Columns (If Needed)

If your `document_translation_requests` table already exists but is missing `file_name` and `file_type` columns:

1. In the SQL Editor, click "New Query" again

2. Open the migration file: `supabase/migrations/add_file_name_file_type_columns.sql`

3. Copy the entire contents of that file

4. Paste it into the SQL Editor

5. Click "Run" or press Ctrl+Enter (Cmd+Enter on Mac)

6. You should see messages indicating which columns were added

### Verify the Migrations

After running both migrations, verify they worked:

1. Go to "Table Editor" in your Supabase dashboard

2. You should now see:
   - `languages` table with 122 rows
   - `document_translation_requests` table

#### Verify Languages Table
Click on `languages` to see it should have:
- id (integer, auto-increment)
- name (text)

#### Verify Document Translation Requests Table
Click on `document_translation_requests` to see it should have columns:
   - id
   - requester_id
   - from_language
   - to_language
   - specialization
   - text
   - title
   - comment
   - translation_method
   - file_url
   - file_type
   - file_name (this is the one that was missing!)
   - status
   - accepted_by
   - accepted_at
   - completed_at
   - created_at
   - translated_text
   - translated_file_url

### Important Note About PostgREST Cache

If you still see errors after applying the migration, PostgREST (the API layer) might have cached the old schema. 

**This is likely your issue!** The cache can take 1-2 minutes to refresh. Try these solutions:

#### Solution 1: Wait and Retry (Easiest)
Wait 2-3 minutes, then try the app again. PostgREST cache refreshes automatically.

#### Solution 2: Restart Supabase (If running locally)
If you're running Supabase locally:
```bash
supabase stop
supabase start
```

#### Solution 3: Force Cache Refresh
There's no direct "Clear Cache" button in Supabase dashboard, but you can:

1. Go to your Supabase dashboard
2. Navigate to Settings > API
3. Look for any cache-related settings

Or make any small schema change (like adding a comment):
```sql
COMMENT ON COLUMN document_translation_requests.file_name IS 'Original filename';
```

#### Solution 4: Check Column Exists
Run this query in SQL Editor to verify columns exist:
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'document_translation_requests' 
AND column_name IN ('file_name', 'file_type');
```

If you see both columns listed, the cache just needs time to refresh. Wait 1-2 minutes.

## Storage Bucket Issue

The code also had a typo in the storage bucket name. This has been fixed from `'doucment'` to `'documents'`. 

Make sure you have a storage bucket named `documents` in your Supabase project:

1. Go to "Storage" in your Supabase dashboard
2. Create a bucket named `documents` if it doesn't exist
3. Set it to "Public bucket" if you want public access to uploaded files

## Next Steps

After applying the migration:

1. Restart your Flutter app
2. Try creating a document translation request again
3. The "language not loaded yet" error should also be resolved once the table exists

## Troubleshooting

### Still getting the error?
- Check that the migration file was actually run (check Table Editor)
- Wait a few minutes for PostgREST cache to clear
- Check your app logs to see the exact error message
- Verify you're connected to the correct Supabase project

### Languages still not loading?
- **First**: Make sure you ran `create_and_seed_languages_table.sql` (Step 1 above)
- Verify the `languages` table exists in your database
- Check that it has 122 rows
- The app caches languages, so try force-refreshing by uninstalling and reinstalling
- Or clear the app data from device settings and restart the app

### Storage upload failing?
- Verify the `documents` bucket exists
- Check bucket permissions (should allow authenticated uploads)
- Verify your Supabase storage is properly configured

## Contact

If you continue to have issues after following these steps, provide:
1. The exact error message you're seeing
2. Screenshots of your Supabase Table Editor showing the tables
3. Logs from your Flutter app

