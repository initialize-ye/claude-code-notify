param(
    [string]$Title = "Claude Code",
    [string]$Body = ""
)

# If no args, try reading stdin JSON (Claude Code hook pipes JSON here)
if ([string]::IsNullOrEmpty($Body) -and -not [Console]::IsInputRedirected) {
    $stdin = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrEmpty($stdin)) {
        try {
            $data = $stdin | ConvertFrom-Json
            $Body = $data.message -or $data.notification
        } catch {}
    }
}

if ([string]::IsNullOrEmpty($Body)) {
    $Body = "Task completed!"
}

# Escape XML special chars
$safeTitle = $Title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
$safeBody  = $Body  -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'

try {
    # Load WinRT types
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
    # Silent fail - don't block Claude Code
}
