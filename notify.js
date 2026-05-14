const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const title = process.argv[2] || "Claude Code";
let body = process.argv[3] || "";

// Escape characters that break PowerShell single-quoted strings
function psEscape(s) {
  return s.replace(/'/g, "''");
}

function showNotification(t, b) {
  const ps1 = path.join(__dirname, "notify.ps1");

  // Fallback: if ps1 doesn't exist, exit silently
  if (!fs.existsSync(ps1)) return;

  const safeT = psEscape(t);
  const safeB = psEscape(b);

  const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${ps1}" -Title '${safeT}' -Body '${safeB}'`;
  exec(cmd, { timeout: 15000, windowsHide: true }, (err) => {
    if (err) process.exit(1);
  });
}

// Read stdin JSON from Claude Code hook
if (!process.stdin.isTTY) {
  let data = "";
  const rl = readline.createInterface({ input: process.stdin });
  rl.on("line", (line) => (data += line));
  rl.on("close", () => {
    if (data) {
      try {
        const parsed = JSON.parse(data);
        body = body || parsed.message || parsed.notification || "";
      } catch {
        // Invalid JSON, use fallback
      }
    }
    if (!body) body = "Task completed!";
    showNotification(title, body);
  });
} else {
  if (!body) body = "Task completed!";
  showNotification(title, body);
}
