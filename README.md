# Claude Code Notify

Windows toast notification for Claude Code CLI task completion.

When Claude finishes a task, a toast notification pops up so you can switch away without missing completion.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

This adds a `Notification` hook to your global Claude Code settings (`~/.claude/settings.json`).

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## How It Works

Uses Claude Code's built-in [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks). The `Notification` event fires when Claude Code wants to alert you (task done, waiting for input). The hook triggers `notify.ps1` which sends a native Windows toast notification with sound.

No external dependencies — uses the Windows WinRT toast API.

## Manual Usage

```powershell
# Send a custom notification
powershell -File notify.ps1 -Title "Hello" -Body "Something happened"

# Pipe JSON from stdin (as Claude Code hooks do)
echo '{"message":"Task completed!"}' | powershell -File notify.ps1
```
