# Startup check: ensure Notification hook exists in Claude Code settings
# Runs silently at Windows logon via registry Run key

$ErrorActionPreference = "SilentlyContinue"

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

# Derive script directory from this script's own path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$notifyJsPath = Join-Path $scriptDir "notify.js"

# Prerequisites check
if (-not (Test-Path $claudeSettingsPath)) { exit 0 }
if (-not (Test-Path $notifyJsPath)) { exit 0 }

# Check if node.exe is available
$nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodeExe) { exit 0 }

# Read current settings
try {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) { exit 0 }
} catch {
    exit 0
}

# Check if hook already exists and is valid
$hasHook = $false
try {
    if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
        $notif = $settings.hooks.Notification
        if ($notif -and $notif.Count -gt 0) {
            $cmd = $notif[0].hooks[0].command
            if ($cmd -and $cmd -like "*notify.js*") {
                $hasHook = $true
            }
        }
    }
} catch {}

if ($hasHook) { exit 0 }

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
try {
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
} catch {}
