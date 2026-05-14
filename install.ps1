# Install Claude Code notification hook
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Claude Code Notify - Installation ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check notify.js
Write-Host "[1/5] Checking notification script..." -ForegroundColor Yellow
$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$scriptDir = $PSScriptRoot
$notifyScript = Join-Path $scriptDir "notify.js"

if (-not (Test-Path $notifyScript)) {
    Write-Host "  ERROR: notify.js not found at: $notifyScript" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "  Found: $notifyScript" -ForegroundColor Gray

# Step 2: Check Node.js
Write-Host "[2/5] Checking Node.js..." -ForegroundColor Yellow
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    Write-Host "  ERROR: Node.js not found. Please install Node.js first." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
$nodeVersion = (node --version 2>$null)
Write-Host "  Found: $nodePath ($nodeVersion)" -ForegroundColor Gray

# Step 3: Read settings
Write-Host "[3/5] Reading Claude Code settings..." -ForegroundColor Yellow
$settingsDir = Split-Path $claudeSettingsPath -Parent
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    Write-Host "  Created directory: $settingsDir" -ForegroundColor Gray
}

$settings = New-Object PSObject
if (Test-Path $claudeSettingsPath) {
    try {
        $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
        $settings = $raw | ConvertFrom-Json
        if (-not $settings) { $settings = New-Object PSObject }
        Write-Host "  Loaded existing settings." -ForegroundColor Gray
    } catch {
        Write-Host "  WARNING: settings.json is corrupted, will create a new one." -ForegroundColor Yellow
        $settings = New-Object PSObject
    }
} else {
    Write-Host "  No existing settings found, will create new." -ForegroundColor Gray
}

# Step 4: Write hook config
Write-Host "[4/5] Writing notification hook..." -ForegroundColor Yellow
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

try {
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Hook config written to: $claudeSettingsPath" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Failed to write settings.json: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 5: Register startup entry
Write-Host "[5/5] Registering startup auto-repair..." -ForegroundColor Yellow
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $checkScript = Join-Path $scriptDir "startup-check.ps1"
    if (Test-Path $checkScript) {
        $regValue = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$checkScript`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
        Write-Host "  Startup entry registered in registry." -ForegroundColor Gray
    } else {
        Write-Host "  WARNING: startup-check.ps1 not found, skipping." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  WARNING: Could not register startup entry: $_" -ForegroundColor Yellow
}

# Done
Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart Claude Code for the hook to take effect." -ForegroundColor White
Write-Host "  After restart, task completion will trigger a Windows notification." -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
