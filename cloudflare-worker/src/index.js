const GROQ_MODEL = "llama-3.3-70b-versatile";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-App-Key",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {"Content-Type": "application/json", ...corsHeaders},
  });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {headers: corsHeaders});
    }
    if (request.method !== "POST") {
      return json({error: "Only POST is supported."}, 405);
    }

    // Simple shared-secret check so a random person who finds this URL
    // can't burn through the Groq quota. Not real user auth - just abuse
    // prevention for a personal-use endpoint.
    const appKey = request.headers.get("X-App-Key");
    if (!appKey || appKey !== env.APP_SHARED_SECRET) {
      return json({error: "Unauthorized."}, 401);
    }

    let payload;
    try {
      payload = await request.json();
    } catch (e) {
      return json({error: "Invalid JSON body."}, 400);
    }

    const {items, occasion} = payload || {};
    if (!Array.isArray(items) || items.length === 0) {
      return json({error: "items must be a non-empty array."}, 400);
    }
    if (typeof occasion !== "string" || occasion.trim() === "") {
      return json({error: "occasion is required."}, 400);
    }

    const wardrobeList = items
      .map((i) =>
        `id=${i.id} category=${i.category} colour=${i.colour} ` +
        `pattern=${i.pattern} style=${i.style} season=${i.season}`)
      .join("\n");

    const prompt = `You are a personal fashion stylist. Choose ONE outfit ` +
      `for the occasion "${occasion}" using ONLY the wardrobe items listed ` +
      `below - never invent items. Prefer good colour harmony and ` +
      `occasion-appropriate formality.

Wardrobe items:
${wardrobeList}

Respond with strict JSON only, no markdown, matching this shape:
{"topId": number, "bottomId": number|null, "shoeId": number|null, "accessoryId": number|null, "reasoning": string}

Rules:
- topId must reference a "tops" or "dresses" item id from the list.
- If topId is a "dresses" item, bottomId must be null.
- Only use ids that exist in the wardrobe list above.
- reasoning should be 1-2 short sentences explaining the colour/style choice.`;

    const groqResponse = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${env.GROQ_API_KEY}`,
        },
        body: JSON.stringify({
          model: GROQ_MODEL,
          messages: [{role: "user", content: prompt}],
          response_format: {type: "json_object"},
          temperature: 0.7,
        }),
      },
    );

    if (!groqResponse.ok) {
      const errText = await groqResponse.text();
      return json({error: `Groq API error: ${groqResponse.status} ${errText}`}, 502);
    }

    const data = await groqResponse.json();
    const content = data.choices && data.choices[0] &&
      data.choices[0].message && data.choices[0].message.content;
    if (!content) {
      return json({error: "Groq returned an empty response."}, 502);
    }

    try {
      return json(JSON.parse(content));
    } catch (e) {
      return json({error: "Could not parse Groq's response as JSON."}, 502);
    }
  },
};
