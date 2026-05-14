# Install Claude Code notification hook

try {
    $ErrorActionPreference = "Stop"

    Write-Host ""
    Write-Host "=== Claude Code Notify - 安装 ===" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Check notify.js
    Write-Host "[1/5] 检查通知脚本..." -ForegroundColor Yellow
    $claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
    $scriptDir = $PSScriptRoot
    $notifyScript = Join-Path $scriptDir "notify.js"

    if (-not (Test-Path $notifyScript)) {
        Write-Host "  错误: notify.js 未找到: $notifyScript" -ForegroundColor Red
        exit 1
    }
    Write-Host "  已找到: $notifyScript" -ForegroundColor Gray

    # Step 2: Check Node.js
    Write-Host "[2/5] 检查 Node.js..." -ForegroundColor Yellow
    $nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
    if (-not $nodePath) {
        Write-Host "  错误: 未找到 Node.js，请先安装 Node.js。" -ForegroundColor Red
        exit 1
    }
    $nodeVersion = (node --version 2>$null)
    Write-Host "  已找到: $nodePath ($nodeVersion)" -ForegroundColor Gray

    # Step 3: Read settings
    Write-Host "[3/5] 读取 Claude Code 配置..." -ForegroundColor Yellow
    $settingsDir = Split-Path $claudeSettingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        Write-Host "  已创建目录: $settingsDir" -ForegroundColor Gray
    }

    $settings = New-Object PSObject
    if (Test-Path $claudeSettingsPath) {
        try {
            $raw = Get-Content $claudeSettingsPath -Raw -Encoding UTF8
            $settings = $raw | ConvertFrom-Json
            if (-not $settings) { $settings = New-Object PSObject }
            Write-Host "  已加载现有配置。" -ForegroundColor Gray
        } catch {
            Write-Host "  警告: settings.json 已损坏，将创建新配置。" -ForegroundColor Yellow
            $settings = New-Object PSObject
        }
    } else {
        Write-Host "  未找到现有配置，将创建新配置。" -ForegroundColor Gray
    }

    # Step 4: Write hook config
    Write-Host "[4/5] 写入通知 hook 配置..." -ForegroundColor Yellow
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

    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($claudeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  hook 配置已写入: $claudeSettingsPath" -ForegroundColor Gray

    # Step 5: Register startup entry
    Write-Host "[5/5] 注册开机自启动..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $checkScript = Join-Path $scriptDir "startup-check.ps1"
    if (Test-Path $checkScript) {
        $regValue = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$checkScript`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
        Write-Host "  开机自启动已注册。" -ForegroundColor Gray
    } else {
        Write-Host "  警告: startup-check.ps1 未找到，跳过。" -ForegroundColor Yellow
    }

    # Done
    Write-Host ""
    Write-Host "=== 安装完成 ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "  重启 Claude Code 后生效。" -ForegroundColor White
    Write-Host "  之后任务完成时将自动弹出 Windows 通知。" -ForegroundColor White

} catch {
    Write-Host ""
    Write-Host "  安装失败: $_" -ForegroundColor Red
} finally {
    Write-Host ""
    Read-Host "按回车键退出"
}
