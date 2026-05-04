import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let q = "";

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      if (typeof body.q === "string") q = body.q;
    } else {
      q = new URL(req.url).searchParams.get("q") ?? "";
    }

    q = q.trim();
    if (!q) {
      return new Response(JSON.stringify({ hits: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const offResponse = await fetch("https://search.openfoodfacts.org/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "FitnessMacros/1.0 (Flutter; contact@example.com)",
      },
      body: JSON.stringify({
        q,
        fields: ["product_name", "nutriments", "brands", "code", "image_front_url"],
        page_size: 20,
      }),
    });

    if (!offResponse.ok) {
      return new Response(
        JSON.stringify({ error: "off_unavailable", status: offResponse.status }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const data = await offResponse.text();
    return new Response(data, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
