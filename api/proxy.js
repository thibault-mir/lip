const https = require("https");
const http = require("http");

export default function handler(req, res) {
  const { url } = req.query;

  if (!url) {
    return res.status(400).send("No URL provided");
  }

  // On choisit le bon module selon le protocole (http ou https)
  const client = url.startsWith("https") ? https : http;

  client
    .get(url, (remoteRes) => {
      // On propage les headers de sécurité pour le navigateur
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader("Access-Control-Allow-Methods", "GET");
      res.setHeader(
        "Content-Type",
        remoteRes.headers["content-type"] || "text/plain",
      );

      // On renvoie le flux directement
      remoteRes.pipe(res);
    })
    .on("error", (err) => {
      console.error(err);
      res.status(500).send("Proxy Error: " + err.message);
    });
}
