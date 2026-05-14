# Startup check: ensure Notification hook exists in Claude Code settings
# Runs silently at Windows logon via registry Run key

$logFile = Join-Path $env:TEMP "claude-notify-startup.log"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $msg" | Out-File -Append -FilePath $logFile -Encoding UTF8
}

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

# Derive script directory from this script's own path
$scriptDir = if ($MyInvocation.MyCommand.Definition) {
    Split-Path -Parent $MyInvocation.MyCommand.Definition
} else { $null }

if (-not $scriptDir) {
    Write-Log "ERROR: Cannot determine script directory"
    exit 1
}

$notifyJsPath = Join-Path $scriptDir "notify.js"

# Prerequisites check
if (-not (Test-Path $claudeSettingsPath)) { exit 0 }
if (-not (Test-Path $notifyJsPath)) {
    Write-Log "WARN: notify.js not found at $notifyJsPath"
    exit 0
}

# Check if node.exe is available
$nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodeExe) {
    Write-Log "WARN: node.exe not found"
    exit 0
}

# Read current settings
try {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) { exit 0 }
} catch {
    Write-Log "ERROR: Failed to read settings.json: $_"
    exit 1
}

# Check if hook already exists and is valid
$hasHook = $false
try {
    if ($settings.PSObject.Properties['hooks']) {
        $hooks = $settings.hooks
        if ($hooks.PSObject.Properties['Notification']) {
            $notif = $hooks.Notification
            if ($notif -and $notif.Count -gt 0) {
                $firstEntry = $notif[0]
                if ($firstEntry.PSObject.Properties['hooks']) {
                    $innerHooks = $firstEntry.hooks
                    if ($innerHooks -and $innerHooks.Count -gt 0) {
                        $cmd = $innerHooks[0].command
                        $expectedPath = $notifyJsPath.Replace('\', '/')
                        if ($cmd -and $cmd -like "*`"$expectedPath`"*") {
                            $hasHook = $true
                        }
                    }
                }
            }
        }
    }
} catch {
    Write-Log "WARN: Hook validation error: $_"
}

if ($hasHook) { exit 0 }

# Re-install the hook
Write-Log "INFO: Hook missing or invalid, reinstalling..."

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

# Backup and write
try {
    if (Test-Path $claudeSettingsPath) {
        Copy-Item $claudeSettingsPath "$claudeSettingsPath.bak" -Force
    }
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Log "INFO: Hook reinstalled successfully"
} catch {
    Write-Log "ERROR: Failed to write settings.json: $_"
    # Restore backup
    if (Test-Path "$claudeSettingsPath.bak") {
        Copy-Item "$claudeSettingsPath.bak" $claudeSettingsPath -Force
        Write-Log "INFO: Restored backup"
    }
}
