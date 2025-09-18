# Send Notification Edge Function

This edge function handles sending push notifications via Firebase Cloud Messaging (FCM).

## Setup Instructions

### 1. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable Cloud Messaging in your project
4. Go to Project Settings > Service Accounts
5. Click "Generate new private key"
6. Download the JSON file

### 2. Configure the Edge Function

1. Rename the downloaded JSON file to `service_account.json`
2. Place it in the `supabase/functions/send-notification/` directory
3. The file should contain your Firebase project credentials

### 3. Deploy the Function

```bash
# Deploy the function to Supabase
supabase functions deploy send-notification
```

### 4. Test the Function

You can test the function locally:

```bash
# Start Supabase locally
supabase start

# Test the function
curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/send-notification' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "title": "Test Notification",
    "body": "This is a test notification",
    "data": {
      "test": "true",
      "type": "test"
    },
    "tokens": ["your_fcm_token_here"]
  }'
```

## Troubleshooting

### Missing Service Account File
If you see "Firebase not configured" in the logs, it means the `service_account.json` file is missing. The function will still return success but won't actually send notifications.

### FCM Token Issues
- Make sure FCM tokens are being registered in the `fcm_tokens` table
- Check that the Firebase project ID in the service account matches your project
- Verify that Cloud Messaging is enabled in your Firebase project

### Database Tables
Make sure these tables exist in your Supabase database:
- `fcm_tokens` - Stores FCM tokens for users
- `interpreter_requests` - Stores interpreter requests
- `notifications` - Stores notification history

## Security Notes

- The service account file contains sensitive credentials
- Never commit the `service_account.json` file to version control
- Add it to your `.gitignore` file
- Use environment variables in production

## Function Response

The function returns a JSON response with:
- `success`: Boolean indicating if the operation was successful
- `successCount`: Number of notifications sent successfully
- `failureCount`: Number of notifications that failed
- `errors`: Array of error details for failed notifications 