import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// In-memory token cache for FCM OAuth2 access token
let cachedAccessToken: string | null = null;
let tokenExpiryTime = 0;

/**
 * Converts a PEM-formatted private key string to an ArrayBuffer.
 */
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleanPem = pem
    .replace(/-----BEGIN [A-Z0-9_-]+-----/g, "")
    .replace(/-----END [A-Z0-9_-]+-----/g, "")
    .replace(/[\r\n\s]/g, "");
  const binary = atob(cleanPem);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Encodes a string or Uint8Array to base64url format.
 */
function base64UrlEncode(data: string | Uint8Array): string {
  let base64: string;
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    let binary = "";
    const len = data.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(data[i]);
    }
    base64 = btoa(binary);
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Retrieves a valid OAuth2 access token for Firebase Cloud Messaging HTTP v1 API.
 */
async function getFcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  project_id: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Return cached token if valid for at least 5 more minutes
  if (cachedAccessToken && tokenExpiryTime > now + 300) {
    return cachedAccessToken;
  }

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const claim = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claim));
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  const binaryKey = pemToArrayBuffer(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(unsignedToken)
  );

  const signature = base64UrlEncode(new Uint8Array(signatureBuffer));
  const signedJwt = `${unsignedToken}.${signature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to obtain Google OAuth2 access token: ${tokenResponse.status} ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  cachedAccessToken = tokenData.access_token;
  tokenExpiryTime = now + (tokenData.expires_in || 3600);

  return cachedAccessToken!;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const { token, tokens, title, body, data, sound, channel_id } = payload;

    const targetTokens: string[] = [];
    if (token && typeof token === "string" && token.trim().length > 0) {
      targetTokens.push(token.trim());
    }
    if (Array.isArray(tokens)) {
      for (const t of tokens) {
        if (typeof t === "string" && t.trim().length > 0 && !targetTokens.includes(t.trim())) {
          targetTokens.push(t.trim());
        }
      }
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing required field: token or tokens" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Load Service Account configuration
    let serviceAccount: { client_email: string; private_key: string; project_id: string } | null = null;

    const rawSaEnv = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (rawSaEnv) {
      try {
        serviceAccount = typeof rawSaEnv === "string" ? JSON.parse(rawSaEnv) : rawSaEnv;
      } catch (e) {
        console.error("Error parsing FIREBASE_SERVICE_ACCOUNT env:", e);
      }
    }

    if (!serviceAccount && payload.service_account) {
      serviceAccount = payload.service_account;
    }

    const projectId = serviceAccount?.project_id || Deno.env.get("FIREBASE_PROJECT_ID") || "findipro-7fe13";

    if (!serviceAccount || !serviceAccount.client_email || !serviceAccount.private_key) {
      console.warn("FIREBASE_SERVICE_ACCOUNT secret not configured in Supabase. Returning informative response.");
      return new Response(
        JSON.stringify({
          error: "FIREBASE_SERVICE_ACCOUNT_NOT_CONFIGURED",
          message: "Please configure FIREBASE_SERVICE_ACCOUNT in Supabase Edge Function secrets with your Firebase service account JSON.",
          projectId,
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getFcmAccessToken(serviceAccount);

    const safeTitle = title || "FindiPro Notification";
    const safeBody = body || "You have a new message";
    const safeChannelId = channel_id || "high_importance_channel";

    // Ensure all data map values are strings (FCM HTTP v1 requirement)
    const stringifiedData: Record<string, string> = {};
    if (data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) {
        stringifiedData[k] = v !== null && v !== undefined ? String(v) : "";
      }
    }

    const results = [];
    let successCount = 0;
    let failureCount = 0;

    for (const fcmToken of targetTokens) {
      const fcmMessage = {
        message: {
          token: fcmToken,
          notification: {
            title: safeTitle,
            body: safeBody,
          },
          data: {
            ...stringifiedData,
            title: safeTitle,
            body: safeBody,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: safeChannelId,
              sound: sound || "default",
              default_vibrate_timings: true,
              priority: "PRIORITY_MAX",
              visibility: "PUBLIC",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                alert: {
                  title: safeTitle,
                  body: safeBody,
                },
                sound: sound || "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
        },
      };

      try {
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(fcmMessage),
          }
        );

        const respText = await fcmResponse.text();
        if (fcmResponse.ok) {
          successCount++;
          results.push({ token: fcmToken, status: "sent", response: JSON.parse(respText) });
        } else {
          failureCount++;
          results.push({ token: fcmToken, status: "failed", statusCode: fcmResponse.status, error: respText });
        }
      } catch (err) {
        failureCount++;
        results.push({ token: fcmToken, status: "error", error: String(err) });
      }
    }

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        successCount,
        failureCount,
        results,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Push dispatch error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
