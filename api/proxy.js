// api/proxy.js
// Proxy Vercel pour contourner les restrictions CORS sur le web
// Supporte les gros fichiers M3U (streaming), HTTP + HTTPS, timeouts

const https = require("https");
const http = require("http");

// Vercel limite les fonctions serverless à 10s par défaut (plan gratuit)
// On configure le timeout à 9s pour rester safe
const REQUEST_TIMEOUT_MS = 9000;

export default function handler(req, res) {
  // CORS preflight
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  const { url } = req.query;

  if (!url) {
    return res.status(400).json({ error: "Missing url parameter" });
  }

  // Validation basique — on accepte seulement HTTP(S)
  let parsedUrl;
  try {
    parsedUrl = new URL(url);
  } catch (e) {
    return res.status(400).json({ error: "Invalid URL" });
  }

  if (!["http:", "https:"].includes(parsedUrl.protocol)) {
    return res.status(400).json({ error: "Only http/https allowed" });
  }

  const client = parsedUrl.protocol === "https:" ? https : http;

  const options = {
    hostname: parsedUrl.hostname,
    port: parsedUrl.port || (parsedUrl.protocol === "https:" ? 443 : 80),
    path: parsedUrl.pathname + parsedUrl.search,
    method: "GET",
    headers: {
      // Certains serveurs IPTV bloquent les requêtes sans User-Agent
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      Accept: "*/*",
    },
    timeout: REQUEST_TIMEOUT_MS,
  };

  const proxyReq = client.request(options, (remoteRes) => {
    // Propagation des headers utiles
    res.setHeader(
      "Content-Type",
      remoteRes.headers["content-type"] || "text/plain; charset=utf-8",
    );
    res.setHeader("Access-Control-Allow-Origin", "*");

    // Statut HTTP du serveur distant
    res.status(remoteRes.statusCode || 200);

    // Streaming direct — gère les très gros fichiers M3U sans OOM
    remoteRes.pipe(res);

    remoteRes.on("error", (err) => {
      console.error("[proxy] remoteRes error:", err.message);
      if (!res.headersSent) {
        res.status(502).json({ error: "Upstream stream error" });
      }
    });
  });

  proxyReq.on("timeout", () => {
    console.error("[proxy] timeout for:", url);
    proxyReq.destroy();
    if (!res.headersSent) {
      res.status(504).json({ error: "Upstream timeout" });
    }
  });

  proxyReq.on("error", (err) => {
    console.error("[proxy] request error:", err.message, "url:", url);
    if (!res.headersSent) {
      res.status(502).json({ error: "Proxy error: " + err.message });
    }
  });

  proxyReq.end();
}
