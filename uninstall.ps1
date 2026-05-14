# Uninstall Claude Code notification hook

try {
    $ErrorActionPreference = "Stop"

    Write-Host ""
    Write-Host "=== Claude Code Notify - 卸载 ===" -ForegroundColor Cyan
    Write-Host ""

    $claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

    # Step 1: Check settings file
    Write-Host "[1/3] 检查配置文件..." -ForegroundColor Yellow
    if (-not (Test-Path $claudeSettingsPath)) {
        Write-Host "  未找到配置文件，无需卸载。" -ForegroundColor Gray
        exit 0
    }
    Write-Host "  已找到: $claudeSettingsPath" -ForegroundColor Gray

    # Step 2: Remove hook
    Write-Host "[2/3] 移除通知 hook..." -ForegroundColor Yellow
    $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
    if (-not $settings) {
        Write-Host "  配置文件为空，无需移除。" -ForegroundColor Gray
    } else {
        $removed = $false
        if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Notification']) {
            $settings.hooks.PSObject.Properties.Remove('Notification')
            $removed = $true

            if ($settings.hooks.PSObject.Properties.Count -eq 0) {
                $settings.PSObject.Properties.Remove('hooks')
            }
        }

        if ($removed) {
            $json = $settings | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  hook 已从配置中移除。" -ForegroundColor Gray
        } else {
            Write-Host "  配置中未找到通知 hook。" -ForegroundColor Gray
        }
    }

    # Step 3: Remove startup entry
    Write-Host "[3/3] 移除开机自启动..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-ItemProperty -Path $regPath -Name $regName -Force
        Write-Host "  开机自启动已移除。" -ForegroundColor Gray
    } else {
        Write-Host "  未找到开机自启动项。" -ForegroundColor Gray
    }

    # Done
    Write-Host ""
    Write-Host "=== 卸载完成 ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "  重启 Claude Code 后生效。" -ForegroundColor White

} catch {
    Write-Host ""
    Write-Host "  卸载失败: $_" -ForegroundColor Red
} finally {
    Write-Host ""
    Read-Host "按回车键退出"
}
