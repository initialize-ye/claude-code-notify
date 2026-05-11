# Claude Code Notify

Claude Code CLI 任务完成时发送 Windows 通知提醒。

当 Claude 完成任务时，自动弹出 Windows Toast 通知，让你切屏干别的事情也不会错过任务完成。

## 安装

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

将 `Notification` hook 添加到全局 Claude Code 配置（`~/.claude/settings.json`）。

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## 工作原理

利用 Claude Code 内置的 [hooks 系统](https://docs.anthropic.com/en/docs/claude-code/hooks)。`Notification` 事件在 Claude Code 需要通知你时触发（任务完成、等待输入等）。hook 触发 `notify.ps1`，通过 Windows 原生 WinRT API 发送带提示音的 Toast 通知。

无任何外部依赖，Windows 10/11 开箱即用。

## 手动使用

```powershell
# 发送自定义通知
powershell -File notify.ps1 -Title "你好" -Body "发生了一些事情"

# 通过 stdin 传入 JSON（与 Claude Code hook 一致的方式）
echo '{"message":"任务完成！"}' | powershell -File notify.ps1
```
