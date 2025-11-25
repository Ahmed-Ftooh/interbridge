# Admin Control Panel - Complete Features

## Overview
The admin panel now has **comprehensive control** over interpreter accounts with the following capabilities:

---

## 🎯 Features Implemented

### 1. **View Interpreter Details**
- ✅ User ID
- ✅ Username
- ✅ Role
- ✅ **Email** (with fallback if not available)
- ✅ Gender
- ✅ Bio
- ✅ Years of Experience
- ✅ Created At date
- ✅ **Account Status Badge** (ACTIVE/SUSPENDED)

### 2. **Manage Verification**
- ✅ Approve & Verify interpreter
- ✅ Revoke verification
- ✅ Real-time status display

### 3. **View Expertise**
- ✅ Languages with fluency levels
- ✅ Specializations
- ✅ Skills

### 4. **Certificate Management**
- ✅ View all uploaded certificates
- ✅ Approve certificates
- ✅ Reject certificates with reason
- ✅ View certificate files

### 5. **✨ NEW: Edit Profile**
- **Edit Username**: Change interpreter's display name
- **Edit Bio**: Update personal description
- **Edit Experience**: Modify years of experience
- Success/error feedback
- Auto-refresh after save

### 6. **✨ NEW: Suspend/Activate Account**
- **Suspend Account**: Disable interpreter access (orange button)
- **Activate Account**: Re-enable suspended accounts (green button)
- Confirmation dialog before action
- Visual status badge shows current state
- Success notification after toggle

### 7. **✨ NEW: Reset Password**
- Send password reset email to interpreter
- Confirmation dialog
- Uses Supabase auth reset flow
- Works with any email address

### 8. **✨ NEW: Delete Account (DANGEROUS)**
- **Permanent deletion** with confirmation
- Shows warning about data loss
- Deletes ALL related data:
  - User profile
  - Interpreter details
  - All certificates (files + records)
  - All languages
  - All skills
  - All specializations
  - Call history
  - Auth account
- Returns to list after deletion

---

## 🎨 UI Improvements

### Status Indicators
- **ACTIVE**: Green badge with checkmark
- **SUSPENDED**: Orange badge with block icon
- Displayed at the top of details screen

### Account Actions Card
New section with 4 action buttons:
1. **Edit Profile** (Blue) - Modify interpreter data
2. **Suspend/Activate** (Orange/Green) - Toggle account status
3. **Reset Password** (Purple) - Send reset email
4. **Delete Account** (Red) - Permanent deletion

### Modern Design
- Card-based layout
- Color-coded buttons
- Icon indicators
- Responsive dialogs
- Success/error snackbars

---

## 🔧 Backend Edge Functions

### 1. `admin-update-profile`
**Purpose**: Update interpreter profile data  
**Endpoint**: `supabase/functions/admin-update-profile`  
**Input**:
```json
{
  "user_id": "uuid",
  "username": "new_username",
  "bio": "Updated bio text",
  "years_experience": 5
}
```
**Actions**:
- Updates `users_profile.username`
- Updates `interpreter_details.bio`
- Updates `interpreter_details.years_experience`
- Requires admin role

---

### 2. `admin-suspend-account`
**Purpose**: Suspend or activate interpreter account  
**Endpoint**: `supabase/functions/admin-suspend-account`  
**Input**:
```json
{
  "user_id": "uuid",
  "suspend": true  // or false to activate
}
```
**Actions**:
- Sets `interpreter_details.is_suspended` flag
- Can be used to prevent interpreters from accessing the app
- Requires admin role

---

### 3. `admin-delete-account`
**Purpose**: Permanently delete interpreter and all data  
**Endpoint**: `supabase/functions/admin-delete-account`  
**Input**:
```json
{
  "user_id": "uuid"
}
```
**Actions** (in order):
1. Delete language skills (`interpreter_language_skills`)
2. Delete skills (`interpreter_skills`)
3. Delete specializations (`interpreter_specializations`)
4. Delete languages (`interpreter_languages`)
5. Delete certificate files from Storage
6. Delete certificate records (`interpreter_certificates`)
7. Delete interpreter details (`interpreter_details`)
8. Delete user profile (`users_profile`)
9. Delete auth user account
- ⚠️ **IRREVERSIBLE** - No recovery possible
- Requires admin role

---

## 📊 Database Changes

### New Column: `is_suspended`
**Table**: `interpreter_details`  
**Type**: `BOOLEAN`  
**Default**: `FALSE`  
**Purpose**: Track suspended accounts  
**Migration**: `20250101000000_add_is_suspended_column.sql`

**Usage**:
```sql
-- Check if account is suspended
SELECT is_suspended FROM interpreter_details WHERE user_id = 'xxx';

-- Suspend account
UPDATE interpreter_details SET is_suspended = TRUE WHERE user_id = 'xxx';

-- Activate account
UPDATE interpreter_details SET is_suspended = FALSE WHERE user_id = 'xxx';
```

---

## 🔒 Security

### Admin Role Verification
All Edge Functions verify:
1. User is authenticated (valid JWT token)
2. User has `role = 'admin'` in `users_profile`
3. Returns 401 Unauthorized if not authenticated
4. Returns 403 Forbidden if not admin

### CORS Headers
All functions include proper CORS headers for web access

### Service Role Key
Functions use `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS policies

---

## 📝 How to Use

### Edit Profile
1. Click interpreter from list
2. Scroll to "Account Actions" section
3. Click "Edit Profile" (blue button)
4. Update username, bio, or experience
5. Click "Save"
6. ✅ Profile refreshes automatically

### Suspend Account
1. Click interpreter from list
2. Scroll to "Account Actions"
3. Click "Suspend Account" (orange button)
4. Confirm action
5. ✅ Badge changes to "SUSPENDED"

### Activate Account
1. Click suspended interpreter
2. Status badge shows "SUSPENDED" (orange)
3. Click "Activate Account" (green button)
4. Confirm action
5. ✅ Badge changes to "ACTIVE"

### Reset Password
1. Click interpreter from list
2. Scroll to "Account Actions"
3. Click "Reset Password" (purple button)
4. Confirm email address
5. ✅ Password reset email sent

### Delete Account
1. Click interpreter from list
2. Scroll to "Account Actions"
3. Click "Delete Account" (red button)
4. ⚠️ Read warning carefully
5. Confirm deletion
6. ✅ Account and all data deleted
7. Returns to interpreter list

---

## 🚀 Deployment Steps

### 1. Deploy Edge Functions
```bash
# Deploy all new functions
supabase functions deploy admin-update-profile
supabase functions deploy admin-suspend-account
supabase functions deploy admin-delete-account
```

### 2. Run Migration
```bash
# Add is_suspended column
supabase db push
```

### 3. Test Admin Panel
1. Run app: `flutter run`
2. Login as admin
3. Navigate to Admin screen
4. Click any interpreter
5. Test each new action button

---

## 🐛 Troubleshooting

### Email Not Showing
- Check Edge Function `admin-interpreter-details` returns email in profile object
- Verify `users_profile` table has email column
- Check if email is NULL in database

### Duplicate Certificate
- Cleared in latest version (removed `_MainCertificateTile` widget)
- Only certificate array is now displayed

### Edge Function Errors
- Check Supabase logs: Dashboard → Edge Functions → Logs
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set
- Ensure admin role check is passing

### Suspend Not Working
- Run migration to add `is_suspended` column
- Check function deployment: `supabase functions list`
- Verify RLS policies don't block updates

---

## ✅ Testing Checklist

- [ ] Email displays in Basic Info (or shows "Not available")
- [ ] Status badge shows ACTIVE/SUSPENDED correctly
- [ ] Edit Profile updates username, bio, experience
- [ ] Suspend Account changes status to SUSPENDED
- [ ] Activate Account changes status back to ACTIVE
- [ ] Reset Password sends email successfully
- [ ] Delete Account removes all data
- [ ] All actions show success/error notifications
- [ ] Approve/Reject certificates still work
- [ ] Verification toggle still works

---

## 📦 Files Modified

### Flutter App
- ✅ `lib/admin/screens/admin_list_screen.dart` - Added Account Actions section + methods

### Edge Functions (NEW)
- ✅ `supabase/functions/admin-update-profile/index.ts`
- ✅ `supabase/functions/admin-suspend-account/index.ts`
- ✅ `supabase/functions/admin-delete-account/index.ts`

### Database Migration (NEW)
- ✅ `supabase/migrations/20250101000000_add_is_suspended_column.sql`

---

## 🎉 Summary

You now have **complete admin control** over interpreters:
- ✅ View all details including email
- ✅ Edit profile information
- ✅ Suspend/activate accounts
- ✅ Reset passwords
- ✅ Delete accounts permanently
- ✅ Approve/reject certificates
- ✅ Manage verification status
- ✅ Modern, intuitive UI
- ✅ Secure admin-only access

**Next Steps**:
1. Deploy the 3 new Edge Functions
2. Run the database migration
3. Test all features in the app
4. Enjoy full admin control! 🚀
