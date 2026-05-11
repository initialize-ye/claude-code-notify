param(
    [string]$Title = "Claude Code",
    [string]$Body = ""
)

# Read stdin JSON from Claude Code hook (if piped)
$stdin = ""
if (-not [Console]::IsInputRedirected) {
    $stdin = [Console]::In.ReadToEnd()
}

# Extract message from hook JSON if available
if ([string]::IsNullOrEmpty($Body) -and -not [string]::IsNullOrEmpty($stdin)) {
    try {
        $data = $stdin | ConvertFrom-Json
        if ($data.message) {
            $Body = $data.message
        } elseif ($data.notification) {
            $Body = $data.notification
        }
    } catch {}
}

# Fallback body text
if ([string]::IsNullOrEmpty($Body)) {
    $Body = "Task completed!"
}

# Load WinRT types for toast notifications
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

# Build toast XML
$template = @"
<toast duration="short">
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Body</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)

$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$toast = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
$notification = New-Object Windows.UI.Notifications.ToastNotification($xml)
$toast.Show($notification)
