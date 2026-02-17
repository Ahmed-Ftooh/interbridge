// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// OneSignal Configuration - Get these from your OneSignal dashboard
// Set these as Supabase secrets:
// supabase secrets set ONESIGNAL_APP_ID=your-app-id
// supabase secrets set ONESIGNAL_REST_API_KEY=your-rest-api-key
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';
const ONESIGNAL_ENDPOINT = 'https://onesignal.com/api/v1/notifications';

console.log("OneSignal configuration loaded");
console.log("App ID configured:", ONESIGNAL_APP_ID ? "Yes" : "No");

// Helper function to safely parse JSON
function tryParseJson(str: string): any {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
}

// Main handler
Deno.serve(async (req) => {
  try {
    // Handle CORS
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        },
      });
    }
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const requestBody = await req.json();
    console.log("Raw request body:", JSON.stringify(requestBody));
    console.log("Raw request body type:", typeof requestBody);
    console.log("Raw request body keys:", Object.keys(requestBody || {}));
    
    // Handle different data structures that might be sent
    let title, body, data, playerIds, userIds;
    
    // Try to extract from various possible structures
    // The Supabase Flutter SDK might wrap data in different ways
    const possibleSources = [
      requestBody,                           // Direct
      requestBody?.body,                     // Wrapped in body
      requestBody?.data,                     // Wrapped in data  
      typeof requestBody?.body === 'string' ? tryParseJson(requestBody.body) : null,  // JSON string in body
    ].filter(Boolean);
    
    console.log("Possible sources count:", possibleSources.length);
    
    for (const source of possibleSources) {
      if (source && typeof source === 'object') {
        console.log("Checking source:", JSON.stringify(source).substring(0, 200));
        if (source.title && source.body) {
          title = source.title;
          body = source.body;
          data = source.data;
          playerIds = source.player_ids || source.playerIds;
          userIds = source.user_ids || source.userIds;
          console.log("Found data in source with title:", title);
          break;
        }
      }
    }
    
    console.log("Parsed notification request:", { 
      title, 
      body: body?.substring?.(0, 50) || body, 
      data, 
      playerIdCount: playerIds?.length,
      userIdCount: userIds?.length 
    });

    if (!title || !body) {
      return new Response(JSON.stringify({ error: "Missing required fields: title, body" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // We need either player_ids or user_ids to send notifications
    const hasPlayerIds = Array.isArray(playerIds) && playerIds.length > 0;
    const hasUserIds = Array.isArray(userIds) && userIds.length > 0;
    
    if (!hasPlayerIds && !hasUserIds) {
      return new Response(JSON.stringify({ error: "Missing required fields: player_ids or user_ids" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // Check if OneSignal is configured
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      console.log("OneSignal not configured, returning success without sending notifications");
      return new Response(JSON.stringify({ 
        success: true, 
        successCount: (playerIds?.length || 0) + (userIds?.length || 0), 
        failureCount: 0, 
        errors: [],
        message: "OneSignal not configured - notifications would be sent in production"
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // Build OneSignal notification payload
    const notificationType = data?.type;
    const isIncomingCall = notificationType === 'INCOMING_CALL' || notificationType === 'incoming_call';
    
    console.log("Notification type:", notificationType);
    console.log("Is incoming call:", isIncomingCall);

    // Build base notification
    const notification: Record<string, any> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: body },
      // Additional data to be delivered to the app
      data: data || {},
    };

    // Target by player IDs (subscription IDs) or external user IDs
    if (hasPlayerIds) {
      notification.include_player_ids = playerIds;
    } else if (hasUserIds) {
      // Use external_id for targeting by Supabase user ID
      notification.include_external_user_ids = userIds;
    }

    // Configure for incoming calls - high priority with visible notification
    if (isIncomingCall) {
      // Keep visible notification - required by OneSignal for delivery
      // The app will intercept and show CallKit full-screen UI
      
      // Android high priority settings
      notification.priority = 10; // High priority (10 = max)
      notification.ttl = 60; // 60 seconds TTL for calls
      
      // iOS settings for background delivery
      notification.content_available = true; // Background delivery (iOS & Android)
      notification.mutable_content = true; // Allow notification modification
      
      // Collapse key to prevent duplicate notifications
      notification.collapse_id = `call_${data?.request_id || Date.now()}`;
      
      // Use default notification sound (don't specify custom sounds that may not exist)
      // notification.ios_sound = "default";
      // notification.android_sound = "default";
    } else {
      // Regular notification settings
      notification.priority = 5; // Normal priority
    }

    console.log("Sending OneSignal notification:", JSON.stringify(notification, null, 2));

    // Send notification via OneSignal REST API
    try {
      const res = await fetch(ONESIGNAL_ENDPOINT, {
        method: "POST",
        headers: {
          "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(notification),
      });

      const responseData = await res.json();
      console.log("OneSignal response status:", res.status);
      console.log("OneSignal response data:", JSON.stringify(responseData));
      console.log("OneSignal recipients count:", responseData.recipients);
      console.log("OneSignal notification ID:", responseData.id);
      
      // Check for errors in response
      if (responseData.errors) {
        console.log("OneSignal errors in response:", JSON.stringify(responseData.errors));
      }

      if (res.ok && !responseData.errors) {
        const recipients = responseData.recipients || 0;
        console.log(`Notification sent successfully to ${recipients} recipients`);
        
        return new Response(JSON.stringify({ 
          success: true, 
          successCount: recipients,
          failureCount: 0,
          notificationId: responseData.id,
          errors: [] 
        }), {
          status: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      } else {
        const errors = responseData.errors || [];
        const invalidPlayerIds = responseData.invalid_player_ids || [];
        const invalidExternalUserIds = responseData.invalid_external_user_ids || [];
        
        console.error("OneSignal errors:", errors);
        console.log("Invalid player IDs:", invalidPlayerIds);
        console.log("Invalid external user IDs:", invalidExternalUserIds);
        
        // Clean up invalid player IDs from database
        if (invalidPlayerIds.length > 0) {
          await cleanupInvalidPlayerIds(invalidPlayerIds);
        }
        
        return new Response(JSON.stringify({ 
          success: errors.length === 0, 
          successCount: responseData.recipients || 0,
          failureCount: invalidPlayerIds.length + invalidExternalUserIds.length,
          notificationId: responseData.id,
          errors,
          invalidPlayerIds,
          invalidExternalUserIds,
        }), {
          status: errors.length > 0 ? 400 : 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
    } catch (fetchError) {
      console.error("Error sending OneSignal notification:", fetchError);
      throw fetchError;
    }
  } catch (error) {
    console.error("Error in send-notification function:", error);
    return new Response(JSON.stringify({ error: "Internal server error", details: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});

// Helper function to clean up invalid player IDs from database
async function cleanupInvalidPlayerIds(invalidPlayerIds: string[]) {
  try {
    console.log(`Cleaning up ${invalidPlayerIds.length} invalid player IDs from database`);
    
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    const { error: deleteError } = await supabase
      .from('onesignal_player_ids')
      .delete()
      .in('player_id', invalidPlayerIds);
      
    if (deleteError) {
      console.error("Error cleaning up invalid player IDs:", deleteError);
    } else {
      console.log("Successfully cleaned up invalid player IDs");
    }
  } catch (cleanupError) {
    console.error("Error during player ID cleanup:", cleanupError);
  }
}

