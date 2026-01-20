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

Maxwell monitors Claude Code CLI sessions and shows notification bubbles when Claude is waiting for permission approval. Maxwell will bounce continuously until all prompts are resolved.

### Local Setup

Create the hook scripts on your machine:

**~/.claude/maxwell-hook.sh**
```bash
#!/bin/bash
TOOL="$1"
INPUT=$(cat)
SESSION=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('session_id','x'))" 2>/dev/null)
CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command','')[:30])" 2>/dev/null)
CWD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
mkdir -p /tmp/maxwell_claude
echo "{\"tool\":\"$TOOL\",\"cmd\":\"$CMD\",\"cwd\":\"$CWD\",\"time\":$(date +%s),\"session\":\"$SESSION\"}" > "/tmp/maxwell_claude/$SESSION.json"
```

**~/.claude/maxwell-hook-clear.sh**
```bash
#!/bin/bash
INPUT=$(cat)
SESSION=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('session_id','x'))" 2>/dev/null)
rm -f "/tmp/maxwell_claude/$SESSION.json"
```

Make them executable:
```bash
chmod +x ~/.claude/maxwell-hook.sh ~/.claude/maxwell-hook-clear.sh
```

### Configure Claude

Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Bash"}]},
      {"matcher": "Edit", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Edit"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Write"}]},
      {"matcher": "Read", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Read"}]}
    ],
    "PostToolUse": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook-clear.sh"}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook-clear.sh"}]}]
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

On each remote server, create the same hook scripts as the local setup above. The remote hooks write to `/tmp/maxwell_claude/` locally, and Maxwell reads them via SSH.

1. Create the hook scripts (same as Local Setup section)
2. Configure Claude's `~/.claude/settings.json` (same as Configure Claude section)

### Requirements

- SSH key-based authentication must be set up (no password prompts)
- The remote machine must have `python3` installed

### How It Works

- Maxwell SSHs into each enabled remote every 2 seconds
- Reads any JSON files in `/tmp/maxwell_claude/` on the remote
- Shows notification bubbles with `[server-name]` prefix
- Bubbles stack if multiple servers have pending requests

## Auto-start on Login

```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.maxwell.popup.plist

# Enable
launchctl load ~/Library/LaunchAgents/com.maxwell.popup.plist

# Remove completely
rm ~/Library/LaunchAgents/com.maxwell.popup.plist
```
