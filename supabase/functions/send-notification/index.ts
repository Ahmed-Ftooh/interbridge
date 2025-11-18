// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// JWT and crypto helpers
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

// Use embedded Firebase service account credentials
const serviceAccount = {
  "type": "service_account",
  "project_id": "interbridge-6e3b8",
  "private_key_id": "936b8bc0c418f5b2ed8a4b9dd7feac3505ce0394",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDKeJvRStwnqJ35\ns6Hty3SdD5BVyy5pcodCXtBiHWK8le9FTzj0T0ModTg5rnvofhu0+jsnTKFPkUVY\nO1xLxdiW8/j6QAEcAwx38FesqX9LKNlbiRORXBchWIqPuOjewxCVdYrj3CtzURDG\nt4zotCyPmFvLDu7mpLTmL0M2FUPRPaBHjSMWvgsSIJflgSaKlo2ZLDw3p+c+kM9a\nSvDOcgDm4Q67e6LDGQGEVjg7l3gQHk546AXIendHcTQo62rohlN1L3p/+AzDpxau\nDqHIyPw0grcoG5GJGY1aE5M5sG/d6K4RHAcak3NMcw2ExcETaJSpVIaTMiXdnJEb\n3n52j3XtAgMBAAECggEAHe+7SjTBXHPH99WhiaFdeqOEecry79BpQ1z1fqxNnwik\nOiE+kJDvoxnB2HV+CKAsxJODD4p7B2K5WBRezy1PmvIzy/yOrW+d9lXpALSHB7vg\nd3JLHGD7YojO4/U5KUa6Ov8ILCyvl/tSea9F/Fo3hHvIhruMgzmzLZ2rWGHIhzVL\nphXjEHCKQabTXxyGr0+78CQduGDzvnAu+DWKtM58ez4OYg2lQ0FQ+l7daKFWwK3K\n3TtfVwFAyGi/PE+L6/KYo3mlAnKbcaaQlmnsqqeho3U1hItdlFQJfoiVAgmiMfzz\nEKnOm6auQPpcKWKO5dJ8TAE3uQC5eTizxB1cz0RkWQKBgQD/8wxSQ9bcDq2eKF/v\n9bLPbwUeKRu13xenGyRZ3Or0zCybVfBawWpkMdOHUCWryjPP8AAM9To6Jvendqid\n6JGA8jTkxpcXYUEZrHDZ4+KuTqWQtD+4sMLMm1tFwOlsN2/onS0LrmG9u97Qs4PG\neMM0kU1hishTfw0D8dnyqf8/cwKBgQDKgtq3MFTAUBaj/AJ3hhV7sqHCDYakQkF7\nTDAulEoyXb34tDgUXC2hgTkzBSgoeZO/E2Ni6fSiG/Fyxxx8sxA6z9nCebgXWjVR\nd+gzdPsdXSZOFmr7WzqKyEgWPV7dTMaFXuGHFnT5eHf98mvEK8FgWFg0j7g4gbGA\nCepQZH5dHwKBgQCyDEtn9tVCo9tXCFMkxFCtSFfREVu7ewQjNRhmgu3XeSkWrgPT\nvnTaWmcB3Fk4ViMQ5a3DVdw5k9332u2VW7HMd7Ef7J4yn28AAxtGF+caxo8aSKmD\nO0NnvjMSJQ68PxxUPvKVC6vmpwhrOlXS/TMeIG4qCrcsjldphRbOXj+3zQKBgHta\nmb9cQUOjhSb+KsKDejKO7Nk3Q/xqH1jrX63/xfJIB5+mp0I/o8vs2tqpGX0OEWEi\nfjeSKuFUBA7WGhQbPpeUZCCB5BDVcgTd9SLi7tNEGkEWhrP1LgO7W62wVEiYq5Qx\n505R747GQtD9CYfE31XAenoJ0T0aQvSrFX9Ct3YhAoGAfggUzjlN+D+t4tHb/TRa\n576tcBkuzv5Y+tlv+v5aRqgijZKdbjLrEe0IlGhYJR5WsCySaFTrGWNLbos1ja0C\n4SdGKdIrNZPqRzFMRN21QmiBc50Jwx8kqq13AhhRqkelWkNwGMvWx+qXbwdzyWub\nmPpe745UBTbHZxM68+fir3g=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@interbridge-6e3b8.iam.gserviceaccount.com",
  "client_id": "114403210611062404525",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40interbridge-6e3b8.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
};

const FCM_ENDPOINT = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
console.log("Firebase service account loaded successfully");

// Helper: Base64URL encode (convert base64 to base64url)
function base64urlEncode(data: Uint8Array): string {
  return encodeBase64(data)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// Helper: Create JWT for Google OAuth2
async function createAccessToken() {
  try {
    if (!serviceAccount) {
      throw new Error("Firebase service account not available");
    }

    console.log("Creating access token...");
    const header = { alg: "RS256", typ: "JWT" };
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600; // 1 hour
    const payload = {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat,
      exp,
    };
    
    console.log("JWT payload:", payload);
    
    const enc = (obj: object) => base64urlEncode(new TextEncoder().encode(JSON.stringify(obj)));
    const toSign = `${enc(header)}.${enc(payload)}`;
    
    console.log("Importing private key...");
    let key;
    try {
      key = await crypto.subtle.importKey(
        "pkcs8",
        str2ab(serviceAccount.private_key),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
      );
      console.log("Private key imported successfully");
    } catch (keyError) {
      console.error("Failed to import private key:", keyError);
      throw new Error(`Key import failed: ${keyError.message}`);
    }
    
    console.log("Signing JWT...");
    const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(toSign));
    const jwt = `${toSign}.${base64urlEncode(new Uint8Array(sig))}`;
    
    console.log("JWT created, exchanging for access token...");
    // Exchange JWT for access token
    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
    
    if (!res.ok) {
      const errorText = await res.text();
      console.error("Failed to get access token. Status:", res.status);
      console.error("Error response:", errorText);
      throw new Error(`Failed to get access token: ${res.status} - ${errorText}`);
    }
    
    const tokenResponse = await res.json();
    console.log("Access token obtained successfully");
    return tokenResponse.access_token;
  } catch (error) {
    console.error("Error in createAccessToken:", error);
    throw error;
  }
}

// Helper: Convert PEM to ArrayBuffer
function str2ab(pem: string): ArrayBuffer {
  // Remove header/footer and line breaks
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
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
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
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
    console.log("Raw request body:", requestBody);
    console.log("Raw request body type:", typeof requestBody);
    console.log("Raw request body keys:", Object.keys(requestBody));
    
    // Handle different data structures that might be sent
    let title, body, data, tokens;
    
    // Check if data is wrapped in a 'body' property (common with Supabase functions)
    if (requestBody.body && typeof requestBody.body === 'object') {
      console.log("Data wrapped in 'body' property, extracting...");
      console.log("Body property content:", requestBody.body);
      console.log("Body property keys:", Object.keys(requestBody.body));
      title = requestBody.body.title;
      body = requestBody.body.body;
      data = requestBody.body.data;
      tokens = requestBody.body.tokens;
    } else if (requestBody.body && typeof requestBody.body === 'string') {
      // Check if body is a JSON string that needs to be parsed
      console.log("Body is a JSON string, parsing...");
      try {
        const parsedBody = JSON.parse(requestBody.body);
        console.log("Parsed body content:", parsedBody);
        console.log("Parsed body keys:", Object.keys(parsedBody));
        title = parsedBody.title;
        body = parsedBody.body;
        data = parsedBody.data;
        tokens = parsedBody.tokens;
      } catch (parseError) {
        console.error("Failed to parse JSON body:", parseError);
        title = requestBody.title;
        body = requestBody.body;
        data = requestBody.data;
        tokens = requestBody.tokens;
      }
    } else if (requestBody.data && typeof requestBody.data === 'object') {
      // Check if data is wrapped in a 'data' property
      console.log("Data wrapped in 'data' property, extracting...");
      console.log("Data property content:", requestBody.data);
      console.log("Data property keys:", Object.keys(requestBody.data));
      title = requestBody.data.title;
      body = requestBody.data.body;
      data = requestBody.data.data;
      tokens = requestBody.data.tokens;
    } else {
      // Direct data structure
      console.log("Using direct data structure...");
      title = requestBody.title;
      body = requestBody.body;
      data = requestBody.data;
      tokens = requestBody.tokens;
    }
    
    console.log("Parsed notification request:", { title, body, data, tokenCount: tokens?.length });
    console.log("Data types:", { 
      titleType: typeof title, 
      bodyType: typeof body, 
      dataType: typeof data, 
      tokensType: typeof tokens,
      tokensIsArray: Array.isArray(tokens)
    });
    
    // Additional debugging for the specific fields
    console.log("Title value:", title);
    console.log("Body value:", body);
    console.log("Data value:", data);
    console.log("Tokens value:", tokens);

    if (!title || !body || !Array.isArray(tokens) || tokens.length === 0) {
      return new Response(JSON.stringify({ error: "Missing required fields: title, body, tokens" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // Check if Firebase is configured
    if (!serviceAccount || !FCM_ENDPOINT) {
      console.log("Firebase not configured, returning success without sending notifications");
      return new Response(JSON.stringify({ 
        success: true, 
        successCount: tokens.length, 
        failureCount: 0, 
        errors: [],
        message: "Firebase not configured - notifications would be sent in production"
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // Get access token
    console.log("Attempting to get Firebase access token...");
    let accessToken;
    try {
      accessToken = await createAccessToken();
      console.log("Successfully obtained Firebase access token");
    } catch (tokenError) {
      console.error("Failed to create access token:", tokenError);
      console.error("Token error details:", tokenError.message);
      console.error("Token error stack:", tokenError.stack);
      throw new Error(`Failed to get access token: ${tokenError.message}`);
    }

    // Send notification to each token (FCM HTTP v1 does not support multicast in one call)
    let successCount = 0, failureCount = 0, errors = [];
    const invalidTokens = [];
    
    for (const token of tokens) {
      try {
        const message = {
          message: {
            token,
            notification: { title, body },
            data: data || {},
          },
        };
        
        console.log("Sending notification to token:", token.substring(0, 20) + "...");
        
        const res = await fetch(FCM_ENDPOINT, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        });
        
        if (res.ok) {
          successCount++;
          console.log("Successfully sent notification to token");
        } else {
          failureCount++;
          const errorData = await res.json();
          console.error("Failed to send notification:", errorData);
          
          // Check if token is invalid/unregistered
          if (errorData.error && 
              (errorData.error.code === 404 || 
               errorData.error.details?.some((detail: any) => detail.errorCode === "UNREGISTERED"))) {
            console.log("Token is invalid/unregistered, marking for cleanup:", token.substring(0, 20) + "...");
            invalidTokens.push(token);
          }
          
          errors.push({ 
            token: token.substring(0, 20) + "...", 
            error: errorData,
            isInvalid: errorData.error?.code === 404 || 
                      errorData.error?.details?.some((detail: any) => detail.errorCode === "UNREGISTERED")
          });
        }
      } catch (error) {
        failureCount++;
        errors.push({ token: token.substring(0, 20) + "...", error: error.message });
        console.error("Error sending notification:", error);
      }
    }

    // Clean up invalid tokens from database
    if (invalidTokens.length > 0) {
      try {
        console.log(`Cleaning up ${invalidTokens.length} invalid tokens from database`);
        
        // Use Supabase client to delete invalid tokens
        const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );
        
        const { error: deleteError } = await supabase
          .from('fcm_tokens')
          .delete()
          .in('token', invalidTokens);
          
        if (deleteError) {
          console.error("Error cleaning up invalid tokens:", deleteError);
        } else {
          console.log("Successfully cleaned up invalid tokens");
        }
      } catch (cleanupError) {
        console.error("Error during token cleanup:", cleanupError);
      }
    }

    console.log(`Notification sending completed: ${successCount} success, ${failureCount} failures`);
    
    return new Response(JSON.stringify({ success: true, successCount, failureCount, errors }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    console.error("Error in send-notification function:", error);
    return new Response(JSON.stringify({ error: "Internal server error", details: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});

