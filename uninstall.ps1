# Uninstall Claude Code notification hook

Write-Host ""
Write-Host "=== Claude Code Notify - 卸载 ===" -ForegroundColor Cyan
Write-Host ""

$claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

# Step 1: Check settings file
Write-Host "[1/3] 检查配置文件..." -ForegroundColor Yellow
if (-not (Test-Path $claudeSettingsPath)) {
    Write-Host "  未找到配置文件，无需卸载。" -ForegroundColor Gray
    Write-Host ""
    Read-Host "按回车键退出"
    exit 0
}
Write-Host "  已找到: $claudeSettingsPath" -ForegroundColor Gray

# Step 2: Remove hook
Write-Host "[2/3] 移除通知 hook..." -ForegroundColor Yellow
try {
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) {
        Write-Host "  配置文件为空，无需移除。" -ForegroundColor Gray
    }
} catch {
    Write-Host "  错误: 读取 settings.json 失败: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "按回车键退出"
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
        Write-Host "  hook 已从配置中移除。" -ForegroundColor Gray
    } catch {
        Write-Host "  错误: 写入 settings.json 失败: $_" -ForegroundColor Red
        Write-Host ""
        Read-Host "按回车键退出"
        exit 1
    }
} else {
    Write-Host "  配置中未找到通知 hook。" -ForegroundColor Gray
}

# Step 3: Remove startup entry
Write-Host "[3/3] 移除开机自启动..." -ForegroundColor Yellow
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-ItemProperty -Path $regPath -Name $regName -Force
        Write-Host "  开机自启动已移除。" -ForegroundColor Gray
    } else {
        Write-Host "  未找到开机自启动项。" -ForegroundColor Gray
    }
} catch {
    Write-Host "  警告: 无法移除开机自启动: $_" -ForegroundColor Yellow
}

# Done
Write-Host ""
Write-Host "=== 卸载完成 ===" -ForegroundColor Green
Write-Host ""
Write-Host "  重启 Claude Code 后生效。" -ForegroundColor White
Write-Host ""
Read-Host "按回车键退出"
