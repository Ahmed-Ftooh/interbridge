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
  "private_key_id": "191c126ddb3ba9232b3080150a309f6a8daa1c19",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDpg6hPprhNPE7P\nvQJWyT+72p0RHxLIVtH/nN99/RCsQr1sVeuFYsflZs2pI44DBgyGQALGCr3v1Dgc\nZ5z6dMyYiJB9MlQTPdL33ytLcQBHKkoQVLvhPcFdVSJ711R2xZCxtfa7mJaWaBRU\nEAD/8EPMJCDvFkuHm3iCZxfKaMyARRr3qm1durtUYl4fVJuABaq3y24Lie08BFU4\nhmtXSsMDSFDZQtv3Hg7/LKiGLjB+QTWEcDuzsa8QDABrbL6fj6aVz/Cqx3E/ttUC\n7eZB8zQ/xjfjHs+Uv3pMH+YImB6V/26SmA3wuSBWsazTGOKY6vacb0vNbWpilQJ1\nObwQ4bAlAgMBAAECggEAMr3yOASxbc8aDRg0RumKWObDVLIc4b3D+jh7dCQmmFgU\nU1NET4LMjzPMouFf/ZY16IJGWASDi3bhDoMRYHc68jZSt3HVRS0dB9HN1aHjfpNY\n7r2K6gICX6adTK3Y48pAi+1PhSo+JsbNDAtCPFtYUCbVpT6CASCuih+e0tP9BC4V\n0KrdyZv13VAdZiKi207TXtCy4hcQBC6nWuwCnWZD2R+tWYtfSXpHPRnD3a0DeeMU\nHo/sOUOqDZEusqdPqImDfyD39KkEL9YSaDbp2tiejAT8HYG5XtSD6oOK1p5qv7w9\nEMVGUDm8M94qQmOMgrOVp5dvsE/QWfajvxKzOULggQKBgQD0xIKqC7l1vqienptK\nRGoSuS5Q1IxqxNtlrL+le9+b6KdV/7w+2RlYNDjqk95+ah/UiGz5CQcZnMXaofik\nwaJ7zRv8IgquM4mbYePJuWcVS2V0UZ7rE1IIKS3Xmk+yi79l2B0rZZ6JqbBOUs/K\nFwX8zj2U+Wu09lwNCkM9OHXIIQKBgQD0OvHcqId9+LQJaq8yYvaq0nsSjwVhnlFx\nz0VQ7p6Pd5xQxbP4jBhLl+9216wy4V+YNsbBk2ObmBEz5rf95gfX4kZaNu2IxWrc\ngcFJ0eZkAgfHbKawBdxYkuAgsRiZOslJVcC9O89HPu4Yp0LzHL2C8XZFRs/icHcN\nzH57CP3XhQKBgDegSUm37GgT8mJKDWStc6XZq+r2wwqovmu2/L7xDfpyv0TOH8vw\nrs/a3myBOnlkSOOWNZ3LLW/mrxhm4wkecHzOOmPsoJzCXa2Qa6I2nnS6c84hloo6\nE9SC90YebapYFCFjIg3wxDzo8YZ7T3nQDa5MeLZYkN/JdVYJVQqewDXBAoGAfiU7\n61b4tK4Sf5Kk7weClHSmsM1CYEtfkcMW8FhveXa0PFwBOu1RVyogu2dmP9l8gKg6\nPJ2eIy2GJSKUAgYgIvdykwIv6ibdrQswBKrvrtQFpJGP/vbn+q/SJ9CQ/gQJF2G9\nbYBI7WmpnP43bE556/o/tkR+91xTgcMPyQi54+kCgYEAvWwlTtuiXXeQ45ujOLXL\n1BXY48eZYnr9Q+/InpQEtgGSe9nIKttNlsl12+eETBTDc9ZDZdDdOovZiVgDyv8b\n47AjqwwxwVGN4/RV4aSwqnaxkM3CfRvhmMHNjOPGprGfn2M0eLZLwzmS9bfuIWFk\nFF9yLMqcGUTFz2ZgCf5yn/o=\n-----END PRIVATE KEY-----\n",
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
  if (!serviceAccount) {
    throw new Error("Firebase service account not available");
  }

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
  const enc = (obj: object) => base64urlEncode(new TextEncoder().encode(JSON.stringify(obj)));
  const toSign = `${enc(header)}.${enc(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    str2ab(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(toSign));
  const jwt = `${toSign}.${base64urlEncode(new Uint8Array(sig))}`;

  // Exchange JWT for access token
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error("Failed to get access token");
  const { access_token } = await res.json();
  return access_token;
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
    const accessToken = await createAccessToken();
    console.log("Got Firebase access token");

    // Send notification to each token (FCM HTTP v1 does not support multicast in one call)
    let successCount = 0, failureCount = 0, errors = [];
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
          const err = await res.text();
          errors.push({ token: token.substring(0, 20) + "...", error: err });
          console.error("Failed to send notification:", err);
        }
      } catch (error) {
        failureCount++;
        errors.push({ token: token.substring(0, 20) + "...", error: error.message });
        console.error("Error sending notification:", error);
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

