param(
    [string]$Title = "Claude Code",
    [string]$Body = ""
)

# Read stdin JSON if piped (Claude Code hook mode)
if ([string]::IsNullOrEmpty($Body) -and -not [Console]::IsInputRedirected) {
    try {
        $stdin = [Console]::In.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($stdin)) {
            $data = $stdin | ConvertFrom-Json
            if ($data.message) {
                $Body = $data.message
            } elseif ($data.notification) {
                $Body = $data.notification
            }
        }
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($Body)) {
    $Body = "Task completed!"
}

# Escape XML special characters
function Escape-Xml([string]$s) {
    $s = $s.Replace('&', '&amp;')
    $s = $s.Replace('<', '&lt;')
    $s = $s.Replace('>', '&gt;')
    $s = $s.Replace('"', '&quot;')
    $s = $s.Replace("'", '&apos;')
    return $s
}

$safeTitle = Escape-Xml $Title
$safeBody  = Escape-Xml $Body

# Truncate to avoid excessively long notifications
if ($safeBody.Length -gt 500) {
    $safeBody = $safeBody.Substring(0, 497) + "..."
}

try {
    [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null

    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml = "<?xml version=""1.0"" encoding=""UTF-8""?>
<toast scenario=""urgent"" duration=""long"">
    <visual>
        <binding template=""ToastGeneric"">
            <text>$safeTitle</text>
            <text>$safeBody</text>
        </binding>
    </visual>
    <audio src=""ms-winsoundevent:Notification.Default""/>
</toast>"
    $doc.LoadXml($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show($doc)
} catch {
    # Fallback: try using msg.exe for legacy notification
    try {
        $msg = "$Title - $Body"
        & msg.exe * /TIME:10 $msg 2>$null
    } catch {}
}
