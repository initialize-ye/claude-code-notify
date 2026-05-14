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

# Verify Node.js is available
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    Write-Error "Node.js not found. Please install Node.js first."
    exit 1
}

# Ensure .claude directory exists
$settingsDir = Split-Path $claudeSettingsPath -Parent
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

# Read existing settings or create empty object
$settings = New-Object PSObject
if (Test-Path $claudeSettingsPath) {
    try {
        $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
        $settings = $raw | ConvertFrom-Json
        if (-not $settings) { $settings = New-Object PSObject }
    } catch {
        Write-Warning "settings.json is corrupted, will create a new one."
        $settings = New-Object PSObject
    }
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

# Write back settings
try {
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
} catch {
    Write-Error "Failed to write settings.json: $_"
    exit 1
}

Write-Host "Hook installed: $claudeSettingsPath" -ForegroundColor Green
Write-Host "Notification script: $notifyScript" -ForegroundColor Green
Write-Host ""

# Register startup entry to auto-repair hook after reboot
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $checkScript = Join-Path $scriptDir "startup-check.ps1"
    if (Test-Path $checkScript) {
        $regValue = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$checkScript`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
        Write-Host "Startup entry registered." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not register startup entry: $_"
}

Write-Host ""
Write-Host "Restart Claude Code for the hook to take effect."
