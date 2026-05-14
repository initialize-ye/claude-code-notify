param(
    [string]$Title = "Claude Code",
    [string]$Body = ""
)

# Read stdin JSON if piped (Claude Code hook mode)
if ([string]::IsNullOrEmpty($Body) -and [Console]::IsInputRedirected) {
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
    # Load WinRT types
    [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument,Windows.Data,ContentType=WindowsRuntime] | Out-Null

    # Find registered Claude AppID from Start Menu
    $appId = $null
    try {
        $apps = Get-StartApps | Where-Object { $_.Name -like '*claude*' }
        if ($apps) {
            $first = @($apps)[0]
            $appId = $first.AppID
        }
    } catch {}

    if ([string]::IsNullOrEmpty($appId)) {
        $appId = 'Claude Code'
    }

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
    $toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} catch {
    # Fallback: try using msg.exe for legacy notification
    try {
        $msg = "$Title - $Body"
        & msg.exe * /TIME:10 $msg 2>$null
    } catch {}
}
