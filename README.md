# Maxwell Popup (macOS)

Floating Maxwell GIF that stays on top of all windows with Claude Code integration.

## Build

```bash
swift build -c release
```

## Run

```bash
./run.sh
# or
./.build/release/maxwell-popup
```

## Alias

Add to `~/.zshrc`:
```bash
alias maxwell="/path/to/maxwell-popup/.build/release/maxwell-popup &"
```

## Usage

- **Drag** anywhere to move
- **Hover** to reveal buttons:
  - `⚙️` settings
  - `−` shrink
  - `+` grow
  - `✕` close

## Claude Code Integration

Maxwell monitors Claude Code CLI sessions and shows a notification bubble when Claude is **actually waiting for permission approval**, bouncing until every prompt is resolved. Detection is driven by Claude Code's `Notification` hook, which fires only when a permission prompt is shown to you — so anything that is auto-approved (accept-edits, auto mode, or a matching allow rule) never triggers a false alarm.

### Install the hooks

Copy the four hook scripts to `~/.claude/` and make them executable:

```bash
cp hooks/maxwell-*.sh ~/.claude/
chmod +x ~/.claude/maxwell-*.sh
```

| Script | Hook event | Role |
|--------|-----------|------|
| `maxwell-notify.sh`  | `Notification` | Writes the "waiting" marker when a permission prompt appears |
| `maxwell-context.sh` | `PreToolUse` | Records the last tool/command so the bubble can show it (never triggers a bubble on its own) |
| `maxwell-clear.sh`   | `PostToolUse` / `UserPromptSubmit` / `SessionEnd` | Clears the marker once the tool runs or you respond |
| `maxwell-stop.sh`    | `Stop` | Clears the marker and records a "done" marker |

The scripts require `python3` (already present on macOS) and write valid JSON via `json.dumps`, so commands containing quotes or newlines are handled correctly. Markers live in `/tmp/maxwell_claude/` (waiting), `/tmp/maxwell_claude_ctx/` (context), and `/tmp/maxwell_claude_done/` (done).

### Configure Claude

Add to `~/.claude/settings.json` (merge into any existing `hooks` block):
```json
{
  "hooks": {
    "Notification": [
      {"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-notify.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Bash",  "hooks": [{"type": "command", "command": "~/.claude/maxwell-context.sh Bash"}]},
      {"matcher": "Edit",  "hooks": [{"type": "command", "command": "~/.claude/maxwell-context.sh Edit"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "~/.claude/maxwell-context.sh Write"}]}
    ],
    "PostToolUse":      [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-clear.sh tool"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-clear.sh prompt"}]}],
    "Stop":             [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-stop.sh"}]}],
    "SessionEnd":       [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-clear.sh end"}]}]
  }
}
```

## Remote Claude (SSH) Support

Maxwell can monitor Claude sessions on remote servers via SSH. Maxwell SSHs into configured servers every 2 seconds to check for pending permission requests.

### Configure Remote Servers

1. Hover over Maxwell and click the ⚙️ settings button
2. Click "Add" to add a remote server
3. Fill in the details:
   - **Name**: Display name (e.g., "dev-server")
   - **Host**: Server IP or hostname
   - **User**: SSH username
   - **SSH Key Path**: Path to your SSH private key (default: `~/.ssh/id_rsa`)
4. Enable the checkbox
5. Click "Save"

### Setup on Remote Machine

On each remote server, install the same four hook scripts and `settings.json` hooks as the local setup above. They write markers to the remote's own `/tmp/maxwell_claude/`, and Maxwell reads them over SSH.

1. Copy `hooks/maxwell-*.sh` to the remote's `~/.claude/` and `chmod +x` them
2. Configure the remote's `~/.claude/settings.json` (same as Configure Claude section)

### Requirements

- SSH key-based authentication must be set up (no password prompts)
- The remote machine must have `python3` installed

### How It Works

- Maxwell SSHs into each enabled remote every 2 seconds
- Reads any JSON files in `/tmp/maxwell_claude/` on the remote
- Shows notification bubbles with `[server-name]` prefix
- Bubbles stack if multiple servers have pending requests

## Telegram Notifications

Maxwell can send Telegram notifications when Claude is waiting for permission, with buttons to Accept/Reject directly from Telegram.

### Enable Telegram

1. Hover over Maxwell and click the settings button
2. Go to "Others" tab
3. Check "Telegram notifications"
4. Click "Save"

### Remote Accept/Reject via Telegram

For remote tmux sessions, you can accept or reject Claude's requests directly from Telegram:

1. Make sure you're running Claude inside a tmux session on the remote server
2. Install the hook scripts on the remote (see Setup on Remote Machine) — `maxwell-notify.sh` records the tmux session automatically
3. When Claude waits for permission, you'll receive a Telegram message with "Accept" and "Reject" buttons
4. Pressing a button will SSH to the server and send the appropriate key to the tmux session

**Note:** This only works for remote sessions running in tmux. Local sessions and non-tmux remote sessions will show notifications without buttons.

## Auto-start on Login

```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.maxwell.popup.plist

# Enable
launchctl load ~/Library/LaunchAgents/com.maxwell.popup.plist

# Remove completely
rm ~/Library/LaunchAgents/com.maxwell.popup.plist
```
