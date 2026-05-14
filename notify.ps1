param(
    [string]$Title = "",
    [string]$Body = "",
    [string]$Attribution = "",
    [string]$Cwd = "",
    [bool]$IsError = $false
)

# Load config
$configPath = Join-Path $PSScriptRoot "config.json"
$config = @{
    title         = "Claude Code"
    defaultBody   = "Task completed!"
    showAttribution = $true
    notifyOnIdle  = $true
    sound         = "default"
    duration      = "long"
    actionButtons = $true
    errorStyle    = $true
}
if (Test-Path $configPath) {
    try {
        $loaded = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded.title)         { $config.title = $loaded.title }
        if ($loaded.defaultBody)   { $config.defaultBody = $loaded.defaultBody }
        if ($null -ne $loaded.showAttribution) { $config.showAttribution = $loaded.showAttribution }
        if ($null -ne $loaded.notifyOnIdle)    { $config.notifyOnIdle = $loaded.notifyOnIdle }
        if ($loaded.sound)         { $config.sound = $loaded.sound }
        if ($loaded.duration)      { $config.duration = $loaded.duration }
        if ($null -ne $loaded.actionButtons)   { $config.actionButtons = $loaded.actionButtons }
        if ($null -ne $loaded.errorStyle)      { $config.errorStyle = $loaded.errorStyle }
    } catch {}
}

# Read JSON from stdin (primary method, used by notify.js)
if ([Console]::IsInputRedirected) {
    try {
        $stdin = [Console]::In.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($stdin)) {
            $data = $stdin | ConvertFrom-Json
            if ($data.title)       { $Title = $data.title }
            if ($data.body)        { $Body = $data.body }
            if ($data.attribution) { $Attribution = $data.attribution }
            if ($data.cwd)         { $Cwd = $data.cwd }
            if ($null -ne $data.isError) { $IsError = $data.isError }
        }
    } catch {}
}

# Fallback for direct parameter usage
if ([string]::IsNullOrEmpty($Title)) { $Title = $config.title }

# Filter out generic waiting messages
if ($Body -match "(?i)waiting for your input") {
    $Body = ""
}

if ([string]::IsNullOrWhiteSpace($Body)) {
    $Body = $config.defaultBody
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
$safeAttr  = Escape-Xml $Attribution
$safeCwd   = Escape-Xml $Cwd

# Apply error style
if ($IsError -and $config.errorStyle) {
    $safeTitle = Escape-Xml "$Title [错误]"
}

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

    # Build attribution line
    $attrLine = ""
    if (-not [string]::IsNullOrWhiteSpace($safeAttr)) {
        $attrLine = "<text placement=""attribution"">$safeAttr</text>"
    }

    # Build audio tag
    $audioLine = ""
    switch ($config.sound) {
        "default" { $audioLine = '<audio src="ms-winsoundevent:Notification.Default"/>' }
        "im"      { $audioLine = '<audio src="ms-winsoundevent:Notification.IM"/>' }
        "alarm"   { $audioLine = '<audio src="ms-winsoundevent:Notification.Looping.Alarm"/>' }
        "silent"  { $audioLine = '<audio silent="true"/>' }
        default   { $audioLine = '<audio src="ms-winsoundevent:Notification.Default"/>' }
    }

    # Override sound for error notifications (only if using default sound)
    if ($IsError -and $config.errorStyle -and $config.sound -eq "default") {
        $audioLine = '<audio src="ms-winsoundevent:Notification.Looping.Alarm"/>'
    }

    # Build scenario attribute
    $scenario = ""
    if ($config.duration -eq "persistent") {
        $scenario = ' scenario="reminder"'
    }

    # Build action buttons
    $actionsLine = ""
    if ($config.actionButtons -and -not [string]::IsNullOrWhiteSpace($Cwd)) {
        $actionsLine = @"
<actions>
        <action content="打开项目文件夹" arguments="explorer:$safeCwd" activationType="protocol"/>
    </actions>
"@
    }

    $xml = "<?xml version=""1.0"" encoding=""UTF-8""?>
<toast$scenario duration=""long"">
    <visual>
        <binding template=""ToastGeneric"">
            <text>$safeTitle</text>
            <text>$safeBody</text>
            $attrLine
        </binding>
    </visual>
    $audioLine
    $actionsLine
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
