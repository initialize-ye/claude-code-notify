# Install Claude Code notification hook

try {
    $ErrorActionPreference = "Stop"

    Write-Host ""
    Write-Host "=== Claude Code Notify - 安装 ===" -ForegroundColor Cyan
    Write-Host ""

    # Resolve script directory
    $scriptDir = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Definition) {
        Split-Path -Parent $MyInvocation.MyCommand.Definition
    } else {
        Write-Host "  错误: 无法确定脚本目录，请直接运行 .ps1 文件。" -ForegroundColor Red
        exit 1
    }

    # Step 1: Check notify.js
    Write-Host "[1/5] 检查通知脚本..." -ForegroundColor Yellow
    $claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
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
            Write-Host "  警告: settings.json 解析失败。" -ForegroundColor Yellow
            Write-Host "  原因: $($_.Exception.Message)" -ForegroundColor Gray
            Write-Host ""
            $choice = Read-Host "  是否覆盖损坏的配置？(y/N)"
            if ($choice -ne 'y' -and $choice -ne 'Y') {
                Write-Host "  已取消安装。" -ForegroundColor Yellow
                exit 0
            }
            # Backup the corrupted file
            $bakPath = "$claudeSettingsPath.corrupted.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $claudeSettingsPath $bakPath -Force
            Write-Host "  已备份损坏文件: $bakPath" -ForegroundColor Gray
            $settings = New-Object PSObject
        }
    } else {
        Write-Host "  未找到现有配置，将创建新配置。" -ForegroundColor Gray
    }

    # Step 4: Write hook config
    Write-Host "[4/5] 写入通知 hook 配置..." -ForegroundColor Yellow
    $notifyScriptEscaped = $notifyScript.Replace('\', '/')
    $hookCommand = "node `"$notifyScriptEscaped`""

    # Check if already installed with the same path
    $alreadyInstalled = $false
    if ($settings.PSObject.Properties['hooks'] -and
        $settings.hooks.PSObject.Properties['Notification']) {
        $notif = $settings.hooks.Notification
        if ($notif -and $notif.Count -gt 0) {
            try {
                $existingCmd = $notif[0].hooks[0].command
                if ($existingCmd -eq $hookCommand) {
                    $alreadyInstalled = $true
                }
            } catch {}
        }
    }

    if ($alreadyInstalled) {
        Write-Host "  通知 hook 已安装，无需重复安装。" -ForegroundColor Green
    } else {
        # Backup before writing
        if (Test-Path $claudeSettingsPath) {
            Copy-Item $claudeSettingsPath "$claudeSettingsPath.bak" -Force
            Write-Host "  已备份: $claudeSettingsPath.bak" -ForegroundColor Gray
        }

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
            Write-Host "  hook 配置已写入: $claudeSettingsPath" -ForegroundColor Gray
        } catch {
            # Restore backup on failure
            if (Test-Path "$claudeSettingsPath.bak") {
                Copy-Item "$claudeSettingsPath.bak" $claudeSettingsPath -Force
                Write-Host "  写入失败，已恢复备份。" -ForegroundColor Yellow
            }
            throw
        }
    }

    # Step 5: Register startup entry
    Write-Host "[5/5] 注册开机自启动..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "ClaudeCodeNotifyStartupCheck"
    $checkScript = Join-Path $scriptDir "startup-check.ps1"
    if (Test-Path $checkScript) {
        try {
            $regValue = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$checkScript`""
            Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
            Write-Host "  开机自启动已注册。" -ForegroundColor Gray
        } catch {
            Write-Host "  警告: 注册开机自启动失败，可能被组策略限制。" -ForegroundColor Yellow
            Write-Host "  原因: $($_.Exception.Message)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  警告: startup-check.ps1 未找到，跳过自启动注册。" -ForegroundColor Yellow
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
