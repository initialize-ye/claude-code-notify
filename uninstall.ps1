# Uninstall Claude Code notification hook

Write-Host ""
Write-Host "=== Claude Code Notify - Uninstallation ===" -ForegroundColor Cyan
Write-Host ""

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

# Step 1: Check settings file
Write-Host "[1/3] Checking settings file..." -ForegroundColor Yellow
if (-not (Test-Path $claudeSettingsPath)) {
    Write-Host "  No settings file found. Nothing to uninstall." -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}
Write-Host "  Found: $claudeSettingsPath" -ForegroundColor Gray

# Step 2: Remove hook
Write-Host "[2/3] Removing notification hook..." -ForegroundColor Yellow
try {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) {
        Write-Host "  Settings file is empty. Nothing to remove." -ForegroundColor Gray
    }
} catch {
    Write-Host "  ERROR: Failed to read settings.json: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$removed = $false
if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
    $settings.hooks.PSObject.Properties.Remove('Notification')
    $removed = $true

    if ($settings.hooks.PSObject.Properties.Count -eq 0) {
        $settings.PSObject.Properties.Remove('hooks')
    }
}

if ($removed) {
    try {
        $json = $settings | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  Hook removed from settings." -ForegroundColor Gray
    } catch {
        Write-Host "  ERROR: Failed to write settings.json: $_" -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Host "  No notification hook found in settings." -ForegroundColor Gray
}

# Step 3: Remove startup entry
Write-Host "[3/3] Removing startup entry..." -ForegroundColor Yellow
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-ItemProperty -Path $regPath -Name $regName -Force
        Write-Host "  Startup entry removed from registry." -ForegroundColor Gray
    } else {
        Write-Host "  No startup entry found." -ForegroundColor Gray
    }
} catch {
    Write-Host "  WARNING: Could not remove startup entry: $_" -ForegroundColor Yellow
}

# Done
Write-Host ""
Write-Host "=== Uninstallation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart Claude Code to take effect." -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
