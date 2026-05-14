const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

// Load config
const configPath = path.join(__dirname, "config.json");
let config = {
  title: "Claude Code",
  defaultBody: "Task completed!",
  showAttribution: true,
  notifyOnIdle: true,
  sound: "default",
  duration: "long",
  errorStyle: true,
};
try {
  if (fs.existsSync(configPath)) {
    Object.assign(config, JSON.parse(fs.readFileSync(configPath, "utf-8")));
  }
} catch {}

const title = process.argv[2] || config.title;
let body = process.argv[3] || "";

function showNotification(t, b, attribution, isError) {
  const ps1 = path.join(__dirname, "notify.ps1");

  // Fallback: if ps1 doesn't exist, exit silently
  if (!fs.existsSync(ps1)) return;

  // Pass data as JSON via stdin to avoid quoting issues
  const payload = JSON.stringify({
    title: t,
    body: b,
    attribution: attribution || "",
    isError: !!isError,
  });

  const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${ps1}"`;
  const child = exec(cmd, { timeout: 15000, windowsHide: true }, (err) => {
    if (err) process.exit(1);
  });

  child.stdin.write(payload);
  child.stdin.end();
}

// Extract meaningful text from hook JSON
function extractMessage(parsed) {
  if (parsed.message) return parsed.message;
  if (parsed.notification) return parsed.notification;
  if (parsed.notification && typeof parsed.notification === "object") {
    return parsed.notification.message || parsed.notification.text || "";
  }
  if (parsed.transcript_summary) return parsed.transcript_summary;
  return "";
}

// Extract attribution/context info
function extractAttribution(parsed) {
  if (!config.showAttribution) return "";
  if (parsed.cwd) {
    return path.basename(parsed.cwd);
  }
  return "";
}

// Detect error messages
function detectError(msg) {
  if (!config.errorStyle) return false;
  const lower = (msg || "").toLowerCase();
  return /error|failed|failure|exception|crash|panic|错误|失败|崩溃/.test(lower);
}

// Read stdin JSON from Claude Code hook
if (!process.stdin.isTTY) {
  let data = "";
  const rl = readline.createInterface({ input: process.stdin });
  rl.on("line", (line) => (data += line));
  rl.on("close", () => {
    let attribution = "";
    let isError = false;
    if (data) {
      try {
        const parsed = JSON.parse(data);

        // Log raw JSON for debugging (append, max 10KB)
        try {
          const logFile = path.join(__dirname, "hook-debug.log");
          const entry = `[${new Date().toISOString()}] ${data}\n`;
          const existing = fs.existsSync(logFile) ? fs.statSync(logFile).size : 0;
          if (existing < 10240) {
            fs.appendFileSync(logFile, entry, "utf-8");
          }
        } catch {}

        // Skip idle notifications if configured
        if (!config.notifyOnIdle && parsed.notification_type === "idle_prompt") return;

        body = body || extractMessage(parsed);
        attribution = extractAttribution(parsed);
        isError = detectError(body);
      } catch {
        // Invalid JSON, use fallback
      }
    }
    if (!body) body = config.defaultBody;
    showNotification(title, body, attribution, isError);
  });
} else {
  if (!body) body = config.defaultBody;
  showNotification(title, body);
}
