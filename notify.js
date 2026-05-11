const { exec } = require("child_process");
const readline = require("readline");

const title = process.argv[2] || "Claude Code";
let body = process.argv[3] || "";

function escapeXml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function escapePs(s) {
  // Escape single quotes for PowerShell -Command "..." context
  return s.replace(/'/g, "''");
}

function showNotification(t, b) {
  const xmlTitle = escapeXml(t);
  const xmlBody = escapeXml(b);

  // Use scenario="urgent" to bypass Focus Assist (勿扰模式)
  // so notifications show even during fullscreen video/gaming
  const psCmd = [
    `$x=[Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom,ContentType=WindowsRuntime]::new();`,
    `$x.LoadXml('<?xml version="1.0" encoding="UTF-8"?>`,
    `<toast scenario="urgent" duration="long">`,
    `<visual><binding template="ToastGeneric">`,
    `<text>${escapePs(xmlTitle)}</text>`,
    `<text>${escapePs(xmlBody)}</text>`,
    `</binding></visual>`,
    `<audio src="ms-winsoundevent:Notification.Default"/>`,
    `</toast>');`,
    `[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]|Out-Null;`,
    `[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show($x)`,
  ].join("");

  exec(
    `powershell -NoProfile -ExecutionPolicy Bypass -Command "${psCmd.replace(/"/g, '\\"')}"`,
    { timeout: 10000, windowsHide: true },
    (err) => {
      if (err) process.exit(1);
    }
  );
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
