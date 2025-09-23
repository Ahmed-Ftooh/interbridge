# InterBridge Setup Guide

## Environment Configuration

The app requires environment variables to be configured for proper functionality. Follow these steps:

### 1. Create Environment File

Copy the template file to create your environment configuration:

```bash
cp env.template assets/.env
```

### 2. Configure Supabase

1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy your Project URL and anon public key
4. Update `assets/.env` with these values:

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 3. Configure Agora (for Voice Calls)

1. Sign up for an Agora account at https://console.agora.io/
2. Create a new project
3. Get your App ID and App Certificate
4. Update `assets/.env` with these values:

```
AGORA_APP_ID=your-agora-app-id
AGORA_APP_CERTIFICATE=your-agora-app-certificate
```

### 4. Database Setup

Make sure your Supabase database has the following tables:

- `chat_messages` - for storing chat messages
- `user_profiles` - for user profile information
- `requests` - for interpretation requests

### 5. Edge Functions

Deploy the `generate-agora-token` edge function to your Supabase project for voice call functionality.

## Running the App

After configuring the environment variables:

```bash
flutter pub get
flutter run
```

## Troubleshooting

### Chat View Issues
- If chat messages don't load, check your Supabase configuration
- Ensure the database tables exist and have proper permissions
- Check that the user is properly authenticated

### Call View Issues
- If voice calls don't work, verify your Agora configuration
- Ensure microphone permissions are granted
- Check that the `generate-agora-token` edge function is deployed

### Common Errors
- "Missing required environment variables" - Make sure `assets/.env` exists and is properly configured
- "Voice calling not configured" - Check your Agora App ID configuration
- "Microphone permission required" - Grant microphone permissions in device settings
