const axios = require("axios");

export default async function handler(req, res) {
  const { url } = req.query;
  if (!url) return res.status(400).send("No URL provided");

  try {
    const response = await axios.get(url, { responseType: "arraybuffer" });
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Content-Type", response.headers["content-type"]);
    res.send(response.data);
  } catch (error) {
    res.status(500).send("Error fetching M3U");
  }
}
