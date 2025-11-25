# QUICK FIX - Admin Issues Resolved

## Issues Fixed:

### 1. ✅ Database Migration Error
**Error**: `column "interpreter_id" does not exist`

**Cause**: Migration file `202511160930_add_deleted_at_columns.sql` tried to create an index on non-existent `interpreter_id` column.

**Fix**: Changed index from `(requester_id, interpreter_id)` to `(requester_id, status)`.

**File**: `supabase/migrations/202511160930_add_deleted_at_columns.sql`

---

### 2. ✅ Email Not Showing in Admin Details
**Issue**: Email field showed "Not available" in interpreter details.

**Root Cause**: Email is stored in `auth.users` table, NOT in `users_profile` table.

**Fix**: 
1. Removed `email` from `users_profile` SELECT query
2. Added admin API call to get email from auth:
```typescript
const { data: authUser } = await svc.auth.admin.getUserById(id);
email = authUser.user.email;
```
3. Merged email into profile object in response

**File**: `supabase/functions/admin-interpreter-details/index.ts`

---

### 3. ⚠️ Duplicate Certificate Investigation
**Issue**: User reports seeing certificate twice in Documents section.

**Status**: Code looks correct - only one loop through certificates array. This might be:
- Two actual certificate records in database (user uploaded twice)
- Frontend caching issue
- Need to verify in actual app

**Next Step**: Deploy fixes and test in app to verify.

---

## Deploy Commands:

```bash
# 1. Run database migration (fixed)
supabase db push

# 2. Deploy updated Edge Function (with email field)
supabase functions deploy admin-interpreter-details

# 3. Deploy new admin control functions
supabase functions deploy admin-update-profile
supabase functions deploy admin-suspend-account
supabase functions deploy admin-delete-account

# 4. Test the app
flutter run
```

---

## What to Check After Deploy:

1. ✅ Email now shows in Basic Info section
2. ✅ Gender and Created At also display
3. ✅ Database migration runs without errors
4. ⚠️ Verify if duplicate certificate is still there (may have been data issue)
5. ✅ Test all new admin actions (Edit Profile, Suspend, Reset Password, Delete)

---

## If Duplicate Certificate Persists:

Check database directly:
```sql
-- See all certificates for a user
SELECT id, file_name, certificate_type, uploaded_at, status 
FROM interpreter_certificates 
WHERE user_id = 'USER_ID_HERE';
```

If there are actually 2 records, you can delete one:
```sql
-- Delete duplicate (keep the latest)
DELETE FROM interpreter_certificates 
WHERE id = 'DUPLICATE_ID_HERE';
```

---

## Summary:
- ✅ Migration fixed (changed to `requester_id, status`)
- ✅ Email field added to Edge Function response
- ⚠️ Certificate duplicate needs verification after deploy
