// Supabase Edge Function: LINE Push Notification
// Deploy: supabase functions deploy line-notify --no-verify-jwt
// Secret:  supabase secrets set LINE_CHANNEL_TOKEN=your_long_lived_token

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const LINE_TOKEN = Deno.env.get("LINE_CHANNEL_TOKEN");
    if (!LINE_TOKEN) return new Response("LINE_CHANNEL_TOKEN not set", { status: 500, headers: CORS });

    const { lineUserIds, message } = await req.json() as { lineUserIds: string[]; message: string };
    if (!lineUserIds?.length || !message) {
      return new Response("Missing lineUserIds or message", { status: 400, headers: CORS });
    }

    // Send to each LINE user ID
    const results = await Promise.allSettled(
      lineUserIds.map((to) =>
        fetch("https://api.line.me/v2/bot/message/push", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${LINE_TOKEN}`,
          },
          body: JSON.stringify({
            to,
            messages: [{ type: "text", text: message }],
          }),
        })
      )
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    return new Response(JSON.stringify({ sent, total: lineUserIds.length }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(String(e), { status: 500, headers: CORS });
  }
});
