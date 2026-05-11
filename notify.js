const notifier = require("node-notifier");
const path = require("path");
const readline = require("readline");

// If arguments provided, use them directly
const title = process.argv[2] || "Claude Code";
let body = process.argv[3] || "";

function showNotification(t, b) {
  notifier.notify(
    {
      title: t,
      message: b,
      sound: true,
      wait: false,
      icon: path.join(__dirname, "icon.png"),
    },
    (err) => {
      if (err) process.exit(1);
    }
  );
}

// If stdin is piped, read JSON (Claude Code hook mode)
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
  // Direct call mode
  if (!body) body = "Task completed!";
  showNotification(title, body);
}
