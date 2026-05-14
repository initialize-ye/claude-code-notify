# Claude Code Notify

Claude Code CLI 任务完成时发送 Windows 通知提醒。

当 Claude 完成任务时，自动弹出 Windows Toast 通知，让你切屏干别的事情也不会错过任务完成。

## 前置条件

- Windows 10 / 11
- Node.js（已安装）
- Claude Code CLI（已安装）

## 安装

```powershell
cd D:\cy\Desktop\Code\Notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

安装脚本会：
1. 在 `~/.claude/settings.json` 中添加 `Notification` hook
2. 注册开机自启动（注册表 Run 键），重启后自动检查并修复 hook 配置

## 卸载

```powershell
cd D:\cy\Desktop\Code\Notify
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## 通知效果

- 任务完成时 Windows 右下角弹出 Toast 通知
- 使用 `scenario="urgent"` 绕过专注助手，全屏看视频/游戏时也能弹出
- 带有默认系统提示音
- 消息超过 500 字符自动截断

## 工作原理

利用 Claude Code 内置的 [hooks 系统](https://docs.anthropic.com/en/docs/claude-code/hooks)。`Notification` 事件在 Claude Code 需要通知你时触发（任务完成、等待输入等）。

```
Claude Code hook → notify.js → notify.ps1 → Windows Toast
                  (解析 JSON)   (WinRT API)
```

- `notify.js`：Node.js 作为 hook 入口，快速启动，解析 stdin JSON，转调 notify.ps1
- `notify.ps1`：使用 Windows WinRT API 发送 toast 通知，`scenario="urgent"` 绕过专注助手
- `startup-check.ps1`：开机时自动检查 hook 配置，丢失则自动修复

WinRT 不可用时自动 fallback 到 `msg.exe`。

## 手动使用

```powershell
cd D:\cy\Desktop\Code\Notify

# 发送自定义通知
node notify.js "标题" "通知内容"

# 通过 stdin 传入 JSON（与 Claude Code hook 一致的方式）
echo '{"message":"任务完成！"}' | node notify.js
```

## 项目结构

```
├── notify.js            # hook 入口（Node.js）
├── notify.ps1           # Toast 通知发送（PowerShell WinRT）
├── install.ps1          # 安装 hook + 注册开机自启动
├── uninstall.ps1        # 卸载 hook + 清除自启动
├── startup-check.ps1    # 开机自动检查并修复 hook
├── package.json
└── README.md
```
