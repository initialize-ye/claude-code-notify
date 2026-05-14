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
1. 检查 notify.js 和 Node.js 是否存在
2. 在 `~/.claude/settings.json` 中添加 Notification hook（已安装则跳过）
3. 注册开机自启动，重启后自动检查并修复 hook 配置
4. 引导配置通知选项（标题、提示音、时长等）
5. 可选发送测试通知预览效果

## 卸载

```powershell
cd D:\cy\Desktop\Code\Notify
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## 配置选项

安装时可配置以下选项，也可直接编辑 `config.json`：

| 选项 | 字段 | 可选值 | 默认值 |
|------|------|--------|--------|
| 通知标题 | `title` | 任意文字 | Claude Code |
| 默认通知内容 | `defaultBody` | 任意文字 | Task completed! |
| 显示项目名 | `showAttribution` | true/false | true |
| 等待输入通知 | `notifyOnIdle` | true/false | true |
| 提示音 | `sound` | default / im / alarm / silent | default |
| 显示时长 | `duration` | short / long / persistent | long |
| 错误通知样式 | `errorStyle` | true/false | true |

### config.json 示例

```json
{
  "title": "Claude Code",
  "defaultBody": "Task completed!",
  "showAttribution": true,
  "notifyOnIdle": true,
  "sound": "default",
  "duration": "long",
  "errorStyle": true
}
```

## 功能说明

### 通知内容
- 任务完成时显示 Claude 返回的具体消息
- 没有具体消息时显示默认内容（可自定义）
- 通知底部显示当前项目名称（如 `Notify`）
- 消息超过 500 字符自动截断

### 提示音
- `default` — 系统默认通知音
- `im` — IM 消息音
- `alarm` — 闹钟音
- `silent` — 静音

### 显示时长
- `short` — 短（约 5 秒）
- `long` — 长（约 25 秒）
- `persistent` — 常驻直到手动关闭

### 错误通知
当消息包含 error、failed、失败、错误等关键词时：
- 标题自动添加 `[错误]` 前缀
- 提示音切换为闹钟音（仅在使用默认音效时）

### 等待输入通知
Claude 等待用户输入时也会弹通知，通知内容会自动过滤掉 "Claude is waiting for your input" 文字。

## 工作原理

利用 Claude Code 内置的 [hooks 系统](https://docs.anthropic.com/en/docs/claude-code/hooks)。`Notification` 事件在 Claude Code 需要通知你时触发。

```
Claude Code hook → notify.js → notify.ps1 → Windows Toast
                  (解析 JSON)   (WinRT API)
```

- `notify.js` — hook 入口，读取 config.json，解析 stdin JSON，过滤无效通知，转调 notify.ps1
- `notify.ps1` — 使用 WinRT API 发送 toast 通知，根据 config 应用音效/时长/样式
- `startup-check.ps1` — 开机自动检查 hook 配置，丢失则自动修复，错误写入日志
- `config.json` — 用户配置文件
- `install.ps1` — 安装脚本，带重复检测、备份恢复、交互式配置
- `uninstall.ps1` — 卸载脚本，带未安装检测、备份恢复

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
├── config.json          # 用户配置文件
├── install.ps1          # 安装 hook + 注册开机自启动 + 配置选项
├── uninstall.ps1        # 卸载 hook + 清除自启动
├── startup-check.ps1    # 开机自动检查并修复 hook
├── package.json
└── README.md
```
