// Supabase Edge Function: LINE Push Notification
// Deploy with: supabase functions deploy line-notify --no-verify-jwt

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const LINE_TOKEN = Deno.env.get("LINE_CHANNEL_TOKEN");
    if (!LINE_TOKEN) return new Response("LINE_CHANNEL_TOKEN not set", { status: 500, headers: CORS });

    const { lineUserIds, message } = await req.json();
    if (!lineUserIds?.length || !message) {
      return new Response("Missing lineUserIds or message", { status: 400, headers: CORS });
    }

    // Send to each LINE user ID and collect results with LINE API response
    const results = await Promise.all(
      lineUserIds.map(async (to: string) => {
        const res = await fetch("https://api.line.me/v2/bot/message/push", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${LINE_TOKEN}`,
          },
          body: JSON.stringify({ to, messages: [{ type: "text", text: message }] }),
        });
        const body = await res.text();
        return { to, status: res.status, body };
      })
    );

    const errors = results.filter(r => r.status !== 200);
    const sent = results.length - errors.length;

    return new Response(JSON.stringify({ sent, total: lineUserIds.length, errors }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(String(e), { status: 500, headers: CORS });
  }
});
