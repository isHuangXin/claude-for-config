/**
 * Databricks Proxy for Claude Code
 * 透传客户端模型名（加 databricks- 前缀），默认 databricks-claude-opus-5
 */

const http = require("http");

const DATABRICKS_HOST = process.env.DATABRICKS_HOST
  || "https://adb-2607362424041685.5.azuredatabricks.net";
const DATABRICKS_TOKEN = process.env.DATABRICKS_TOKEN;
const DEFAULT_MODEL = "databricks-claude-opus-5";
const PROXY_PORT = 8082;
const MAX_TOKENS_CAP = 64000;

// Force adaptive thinking at this effort on opus-5 for max capability.
// Set FORCE_EFFORT="" to passthrough whatever the client sends.
const FORCE_EFFORT = process.env.FORCE_EFFORT ?? "high";

const PROXY_API_KEY = process.env.PROXY_API_KEY || null;

// Fail fast: without a PAT every request would come back as an opaque 401 from
// Databricks, so refuse to start and say exactly what to export.
if (!DATABRICKS_TOKEN) {
  console.error("DATABRICKS_TOKEN is not set - refusing to start.");
  console.error("");
  console.error("  export DATABRICKS_TOKEN='dapi...'");
  console.error("");
  console.error("  Create a token at:");
  console.error(`  ${DATABRICKS_HOST}/settings/user/developer/access-tokens`);
  console.error("");
  console.error("  Override the workspace with DATABRICKS_HOST if needed:");
  console.error("  export DATABRICKS_HOST='https://<workspace>.azuredatabricks.net'");
  process.exit(1);
}

const ALLOWED_FIELDS = [
  "messages", "system", "tools", "tool_choice",
  "max_tokens", "temperature", "top_p", "top_k", "stop_sequences", "stream",
  "thinking", "output_config", "metadata"
];

// Whitelist of betas Databricks accepts. Client-sent betas outside this set are
// dropped — forwarding unknown ones (e.g. advisor-tool) makes upstream 400.
const BETA_WHITELIST = [
  "interleaved-thinking-2025-05-14",
  "context-1m-2025-08-07",
  "fine-grained-tool-streaming-2025-05-14",
  "token-efficient-tools-2025-02-19"
];

// Map client model name to databricks endpoint name
function mapModel(clientModel) {
  if (!clientModel) return DEFAULT_MODEL;
  // Already has databricks- prefix
  if (clientModel.startsWith("databricks-")) return clientModel;
  // claude-opus-5 -> databricks-claude-opus-5
  if (clientModel.startsWith("claude-")) return "databricks-" + clientModel;
  // Fallback
  return DEFAULT_MODEL;
}

function estimateTokens(reqBody) {
  let text = "";
  const walk = (v) => {
    if (typeof v === "string") { text += v + "\n"; return; }
    if (Array.isArray(v)) { v.forEach(walk); return; }
    if (v && typeof v === "object") { Object.values(v).forEach(walk); }
  };
  walk(reqBody.system);
  walk(reqBody.messages);
  walk(reqBody.tools);
  const cjk = (text.match(/[㐀-䶿一-鿿぀-ヿ가-힯]/g) || []).length;
  const rest = text.length - cjk;
  return Math.max(1, cjk + Math.ceil(rest / 4));
}

function sendJson(res, status, obj) {
  const payload = JSON.stringify(obj);
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function authorized(req) {
  if (!PROXY_API_KEY) return true;
  const bearer = (req.headers["authorization"] || "").replace(/^Bearer\s+/i, "");
  return req.headers["x-api-key"] === PROXY_API_KEY || bearer === PROXY_API_KEY;
}

const server = http.createServer((req, res) => {
  const chunks = [];
  req.on("data", chunk => chunks.push(chunk));
  req.on("end", async () => {
    const body = Buffer.concat(chunks).toString("utf8");
    const ts = () => new Date().toLocaleTimeString();

    if (!authorized(req)) {
      console.warn(`[${ts()}] !! auth failed from ${req.socket.remoteAddress}`);
      return sendJson(res, 401, { type: "error", error: { type: "authentication_error", message: "Invalid API key" } });
    }

    let parsedBody = null;
    if (body) {
      try { parsedBody = JSON.parse(body); }
      catch (e) { return sendJson(res, 400, { type: "error", error: { type: "invalid_request_error", message: "Malformed JSON body" } }); }
    }

    if (req.url.includes("/count_tokens")) {
      const n = parsedBody ? estimateTokens(parsedBody) : 1;
      console.log(`[${ts()}] >> count_tokens = ${n}`);
      return sendJson(res, 200, { input_tokens: n });
    }

    if (!parsedBody) {
      return sendJson(res, 400, { type: "error", error: { type: "invalid_request_error", message: "Empty request body" } });
    }

    const isStreaming = parsedBody.stream === true;
    const originalModel = parsedBody.model || "unknown";
    const targetModel = mapModel(originalModel);

    const newBody = {};
    ALLOWED_FIELDS.forEach(f => {
      if (parsedBody[f] !== undefined) newBody[f] = parsedBody[f];
    });
    newBody.model = targetModel;
    newBody.max_tokens = Math.min(newBody.max_tokens || MAX_TOKENS_CAP, MAX_TOKENS_CAP);

    // opus-5 rejects thinking.type "enabled" — it wants adaptive + output_config.effort
    const isOpus5 = targetModel.includes("opus-5");
    if (isOpus5 && FORCE_EFFORT) {
      newBody.thinking = { type: "adaptive" };
      newBody.output_config = { ...(newBody.output_config || {}), effort: FORCE_EFFORT };
    } else if (newBody.thinking?.type === "enabled" && isOpus5) {
      newBody.thinking = { type: "adaptive" };
    }

    // Claude 5 models deprecated temperature outright; with thinking on it must be 1.
    // Sampling params also conflict with thinking. Strip rather than let upstream 400.
    const isClaude5 = /(opus|sonnet)-5/.test(targetModel);
    if (isClaude5 || newBody.thinking) {
      delete newBody.temperature;
      delete newBody.top_p;
      delete newBody.top_k;
    }

    const filteredBodyString = JSON.stringify(newBody);
    const targetUrl = `${DATABRICKS_HOST}/serving-endpoints/anthropic/v1/messages`;

    console.log(`[${ts()}] >> ${originalModel} -> ${targetModel}`
      + `${newBody.output_config?.effort ? " | effort=" + newBody.output_config.effort : ""}`
      + `${isStreaming ? " | stream" : ""}`);

    // Keep only whitelisted betas: client may send ones upstream rejects
    const clientBetas = (req.headers["anthropic-beta"] || "")
      .split(",").map(s => s.trim()).filter(Boolean);
    const dropped = clientBetas.filter(b => !BETA_WHITELIST.includes(b));
    if (dropped.length) console.log(`[${ts()}]    dropped betas: ${dropped.join(",")}`);
    const betas = [...new Set([...clientBetas.filter(b => BETA_WHITELIST.includes(b)),
                               ...BETA_WHITELIST])].join(",");

    try {
      const dbResponse = await fetch(targetUrl, {
        method: "POST",
        headers: {
          "authorization": `Bearer ${DATABRICKS_TOKEN}`,
          "content-type": "application/json",
          "anthropic-version": req.headers["anthropic-version"] || "2023-06-01",
          "anthropic-beta": betas
        },
        body: filteredBodyString
      });

      const outHeaders = {
        "content-type": dbResponse.headers.get("content-type")
          || (isStreaming ? "text/event-stream; charset=utf-8" : "application/json")
      };
      if (isStreaming) {
        outHeaders["cache-control"] = "no-cache";
        outHeaders["connection"] = "keep-alive";
      }
      const reqId = dbResponse.headers.get("x-request-id");
      if (reqId) outHeaders["x-request-id"] = reqId;
      res.writeHead(dbResponse.status, outHeaders);

      if (!dbResponse.body) { res.end(); return; }

      if (dbResponse.status >= 400) {
        const errText = await dbResponse.text();
        console.error(`[Backend Error] ${dbResponse.status}: ${errText.slice(0, 500)}`);
        res.end(errText);
        return;
      }

      const reader = dbResponse.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
      res.end();
      console.log(`[${ts()}] << done`);
    } catch (err) {
      console.error("[Fatal]", err.message);
      if (!res.headersSent) {
        sendJson(res, 502, { type: "error", error: { type: "api_error", message: err.message } });
      } else {
        res.end();
      }
    }
  });
});

server.listen(PROXY_PORT, () => {
  console.log(`🚀 Proxy on http://localhost:${PROXY_PORT}`);
  console.log(`   Model:  pass-through (default ${DEFAULT_MODEL})`);
  console.log(`   Effort: ${FORCE_EFFORT || "passthrough"} (opus-5 adaptive thinking)`);
  console.log(`   Tokens: max_tokens cap ${MAX_TOKENS_CAP}`);
  console.log(`   Auth:   ${PROXY_API_KEY ? "ON" : "OFF"}`);
});
