const { exec } = require("child_process");
const path = require("path");
const readline = require("readline");

const title = process.argv[2] || "Claude Code";
let body = process.argv[3] || "";

function showNotification(t, b) {
  // Escape double quotes for PowerShell -Command
  const safeT = t.replace(/"/g, '\\"');
  const safeB = b.replace(/"/g, '\\"');
  const ps1 = path.join(__dirname, "notify.ps1");
  const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${ps1}" -Title "${safeT}" -Body "${safeB}"`;
  exec(cmd, { timeout: 15000, windowsHide: true }, () => {});
}

if (!process.stdin.isTTY) {
  let data = "";
  const rl = readline.createInterface({ input: process.stdin });
  rl.on("line", (line) => (data += line));
  rl.on("close", () => {
    try {
      const parsed = JSON.parse(data);
      body = body || parsed.message || parsed.notification || "Task completed!";
    } catch {
      body = body || "Task completed!";
    }
    showNotification(title, body);
  });
} else {
  if (!body) body = "Task completed!";
  showNotification(title, body);
}
