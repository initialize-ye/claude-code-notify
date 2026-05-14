# Uninstall Claude Code notification hook
$ErrorActionPreference = "Stop"

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

if (-not (Test-Path $claudeSettingsPath)) {
    Write-Host "No settings file found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Read existing settings
try {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) {
        Write-Host "Settings file is empty. Nothing to uninstall." -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Error "Failed to read settings.json: $_"
    exit 1
}

# Remove Notification hook
$removed = $false
if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
    $settings.hooks.PSObject.Properties.Remove('Notification')
    $removed = $true

    # Clean up empty hooks object
    if ($settings.hooks.PSObject.Properties.Count -eq 0) {
        $settings.PSObject.Properties.Remove('hooks')
    }
}

# Write back
if ($removed) {
    try {
        $json = $settings | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Hook removed from: $claudeSettingsPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to write settings.json: $_"
        exit 1
    }
} else {
    Write-Host "No notification hook found in settings." -ForegroundColor Yellow
}

# Remove startup entry
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-ItemProperty -Path $regPath -Name $regName -Force
        Write-Host "Startup entry removed." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not remove startup entry: $_"
}

Write-Host ""
Write-Host "Uninstall complete. Restart Claude Code to take effect."
