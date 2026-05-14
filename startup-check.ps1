# Startup check: ensure Notification hook exists in Claude Code settings
# Runs silently at Windows logon via Task Scheduler

$ErrorActionPreference = "SilentlyContinue"

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$scriptDir = $PSScriptRoot
$notifyJsPath = Join-Path $scriptDir "notify.js"

# If settings file doesn't exist, nothing to do
if (-not (Test-Path $claudeSettingsPath)) {
    exit 0
}

# If notify.js doesn't exist, nothing to do
if (-not (Test-Path $notifyJsPath)) {
    exit 0
}

# Read current settings
$raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
$settings = $raw | ConvertFrom-Json
if (-not $settings) {
    exit 0
}

# Check if hook already exists
$hasHook = $false
if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
    $notif = $settings.hooks.Notification
    if ($notif -and $notif.Count -gt 0) {
        $hasHook = $true
    }
}

# If hook exists, nothing to do
if ($hasHook) {
    exit 0
}

# Re-install the hook
$notifyJsEscaped = $notifyJsPath.Replace('\', '/')
$hookCommand = "node `"$notifyJsEscaped`""

$hookEntry = [PSCustomObject]@{
    hooks = @(
        [PSCustomObject]@{
            type = "command"
            command = $hookCommand
        }
    )
}

$notifArray = @($hookEntry)

if ($settings.PSObject.Properties['hooks']) {
    $hooks = $settings.hooks
    if ($hooks.PSObject.Properties['Notification']) {
        $hooks.Notification = $notifArray
    } else {
        $hooks | Add-Member -NotePropertyName "Notification" -NotePropertyValue $notifArray -Force
    }
} else {
    $hooksObj = [PSCustomObject]@{
        Notification = $notifArray
    }
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue $hooksObj -Force
}

# Write back
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
