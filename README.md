# Claude Code Notify

Claude Code CLI 任务完成时发送 Windows 通知提醒。

当 Claude 完成任务时，自动弹出 Windows Toast 通知，让你切屏干别的事情也不会错过任务完成。

## 前置条件

- Windows 10 / 11
- Node.js（已安装）
- Claude Code CLI（已安装）

## 安装

进入项目目录，执行安装脚本：

```powershell
cd D:\cy\Desktop\Code\Notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

安装脚本会自动在 `~/.claude/settings.json` 中添加 `Notification` hook 配置。

## 卸载

```powershell
cd D:\cy\Desktop\Code\Notify
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## 通知效果

- 任务完成时 Windows 右下角弹出 Toast 通知
- 带有默认系统提示音
- 支持点击，聚焦回终端窗口

## 工作原理

利用 Claude Code 内置的 [hooks 系统](https://docs.anthropic.com/en/docs/claude-code/hooks)。`Notification` 事件在 Claude Code 需要通知你时触发（任务完成、等待输入等）。

hook 触发 `notify.js`，通过 `node-notifier` 发送原生 Windows Toast 通知（带提示音）。

使用 Node.js 而非 PowerShell，更稳定可靠，不受系统执行策略影响，休眠/重启后依然正常工作。

## 手动使用

```powershell
cd D:\cy\Desktop\Code\Notify

# 发送自定义通知
node notify.js "标题" "通知内容"

# 通过 stdin 传入 JSON（与 Claude Code hook 一致的方式）
echo '{"message":"任务完成！"}' | node notify.js
```
