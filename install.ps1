# Install Claude Code notification hook
$ErrorActionPreference = "Stop"

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$scriptDir = $PSScriptRoot
$notifyScript = Join-Path $scriptDir "notify.js"

# Verify notify.js exists
if (-not (Test-Path $notifyScript)) {
    Write-Error "notify.js not found at: $notifyScript"
    exit 1
}

# Find node.exe
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    Write-Error "Node.js not found. Please install Node.js first."
    exit 1
}

# Read existing settings as PSCustomObject
$settings = New-Object PSObject
if (Test-Path $claudeSettingsPath) {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) { $settings = New-Object PSObject }
}

# Build hook entry
$notifyScriptEscaped = $notifyScript.Replace('\', '/')
$hookCommand = "node `"$notifyScriptEscaped`""

$hookEntry = [PSCustomObject]@{
    hooks = @(
        [PSCustomObject]@{
            type = "command"
            command = $hookCommand
        }
    )
}

# Add or update hooks property
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
$settingsDir = Split-Path $claudeSettingsPath -Parent
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

[System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Installed successfully!" -ForegroundColor Green
Write-Host "Notification hook added to: $claudeSettingsPath"
Write-Host "Notification script: $notifyScript"
Write-Host ""
Write-Host "Restart Claude Code for the hook to take effect."
