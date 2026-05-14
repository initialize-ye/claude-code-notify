const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const title = process.argv[2] || "Claude Code";
let body = process.argv[3] || "";

function showNotification(t, b, attribution) {
  const ps1 = path.join(__dirname, "notify.ps1");

  // Fallback: if ps1 doesn't exist, exit silently
  if (!fs.existsSync(ps1)) return;

  // Pass data as JSON via stdin to avoid quoting issues
  const payload = JSON.stringify({ title: t, body: b, attribution: attribution || "" });

  const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${ps1}"`;
  const child = exec(cmd, { timeout: 15000, windowsHide: true }, (err) => {
    if (err) process.exit(1);
  });

  child.stdin.write(payload);
  child.stdin.end();
}

// Filter: skip notifications that are just "waiting for input"
function shouldSkip(parsed) {
  const type = parsed.notification_type || "";
  if (type === "idle_prompt") return true;

  const msg = (parsed.message || parsed.notification || "").toLowerCase();
  if (msg.includes("waiting for your input")) return true;

  return false;
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
  const parts = [];

  if (parsed.cwd) {
    const dirName = path.basename(parsed.cwd);
    if (dirName) parts.push(dirName);
  }

  if (parsed.session_id) {
    const shortId = parsed.session_id.substring(0, 8);
    if (shortId) parts.push(`Session: ${shortId}`);
  }

  return parts.join(" · ");
}

// Read stdin JSON from Claude Code hook
if (!process.stdin.isTTY) {
  let data = "";
  const rl = readline.createInterface({ input: process.stdin });
  rl.on("line", (line) => (data += line));
  rl.on("close", () => {
    let attribution = "";
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

        // Skip idle/waiting notifications
        if (shouldSkip(parsed)) return;

        body = body || extractMessage(parsed);
        attribution = extractAttribution(parsed);
      } catch {
        // Invalid JSON, use fallback
      }
    }
    if (!body) body = "Task completed!";
    showNotification(title, body, attribution);
  });
} else {
  if (!body) body = "Task completed!";
  showNotification(title, body);
}
