import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, otp_code, name } = await req.json();

    if (!email || !otp_code) {
      return new Response(
        JSON.stringify({ error: "email and otp_code are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    if (!RESEND_API_KEY) {
      return new Response(
        JSON.stringify({ error: "RESEND_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const displayName = name || email.split("@")[0];
    const expiryMinutes = 10;

    const htmlBody = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>FindiPro Verification</title></head>
<body style="margin:0;padding:0;background:#f4f7fa;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f7fa;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <tr><td style="background:linear-gradient(135deg,#06B6D4 0%,#0891B2 100%);padding:32px 24px;text-align:center;">
          <div style="font-size:28px;font-weight:900;color:#ffffff;letter-spacing:-0.5px;">FindiPro</div>
          <div style="font-size:13px;color:rgba(255,255,255,0.85);margin-top:4px;">Find Trusted Professionals Near You</div>
        </td></tr>
        <tr><td style="padding:36px 32px;">
          <p style="margin:0 0 8px 0;font-size:22px;font-weight:700;color:#0f172a;">Hello, ${displayName}! 👋</p>
          <p style="margin:0 0 24px 0;font-size:15px;color:#475569;line-height:1.6;">Use the verification code below to complete your FindiPro registration.</p>
          <div style="background:#f0f9ff;border:2px dashed #06B6D4;border-radius:14px;padding:28px 20px;text-align:center;margin:0 0 24px 0;">
            <div style="font-size:11px;font-weight:600;color:#0891B2;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Your Verification Code</div>
            <div style="font-size:52px;font-weight:900;color:#0891B2;letter-spacing:14px;line-height:1;">${otp_code}</div>
            <div style="margin-top:16px;background:#fef3c7;border-radius:20px;padding:6px 16px;display:inline-block;">
              <span style="font-size:13px;color:#92400e;font-weight:600;">&#x23F1; Expires in ${expiryMinutes} minutes</span>
            </div>
          </div>
          <p style="margin:0 0 20px 0;font-size:14px;color:#64748b;line-height:1.6;">Enter this code on the verification screen. <strong>Do not share this code with anyone.</strong></p>
          <div style="background:#fef2f2;border-left:4px solid #ef4444;border-radius:0 8px 8px 0;padding:12px 16px;">
            <p style="margin:0;font-size:13px;color:#991b1b;">&#x1F512; If you did not create a FindiPro account, please ignore this email.</p>
          </div>
        </td></tr>
        <tr><td style="padding:20px 32px 28px;border-top:1px solid #e2e8f0;text-align:center;">
          <p style="margin:0;font-size:12px;color:#94a3b8;">&#169; 2025 FindiPro. All rights reserved.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    const textBody = `FindiPro Email Verification\n\nHello ${displayName},\n\nYour verification code is: ${otp_code}\n\nThis code expires in ${expiryMinutes} minutes.\nDo NOT share this code with anyone.\n\nIf you did not sign up, ignore this email.\n\n- The FindiPro Team`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "FindiPro <noreply@findipro.com>",
        to: [email],
        subject: `${otp_code} is your FindiPro verification code (expires in ${expiryMinutes} mins)`,
        html: htmlBody,
        text: textBody,
      }),
    });

    const resData = await res.json();
    if (!res.ok) {
      console.error("Resend error:", resData);
      return new Response(JSON.stringify({ error: "Failed to send email", details: resData }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, id: resData.id }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
