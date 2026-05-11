# Uninstall Claude Code notification hook
$ErrorActionPreference = "Stop"

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

if (-not (Test-Path $claudeSettingsPath)) {
    Write-Host "No settings file found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Read existing settings
$raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
$settings = $raw | ConvertFrom-Json
if (-not $settings) {
    Write-Host "Settings file is empty. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Remove Notification hook
if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
    $settings.hooks.PSObject.Properties.Remove('Notification')

    # Clean up empty hooks object
    if ($settings.hooks.PSObject.Properties.Count -eq 0) {
        $settings.PSObject.Properties.Remove('hooks')
    }

    # Write back
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Uninstalled successfully!" -ForegroundColor Green
    Write-Host "Notification hook removed from: $claudeSettingsPath"
} else {
    Write-Host "No notification hook found in settings. Nothing to uninstall." -ForegroundColor Yellow
}
