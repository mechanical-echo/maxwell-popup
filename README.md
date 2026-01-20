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
  - `−` shrink
  - `+` grow
  - `✕` close

## Claude Code Integration

Maxwell monitors Claude Code CLI sessions and shows notification bubbles when Claude is waiting for permission approval. Maxwell will bounce continuously until all prompts are resolved.

### Setup Hooks

Create the hook scripts:

**~/.claude/maxwell-hook.sh**
```bash
#!/bin/bash
TOOL="$1"
INPUT=$(cat)

SESSION=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null)

if [ "$TOOL" = "Bash" ]; then
    CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command','')[:30])" 2>/dev/null)
else
    CMD=$(echo "$INPUT" | python3 -c "import sys,json,os; d=json.load(sys.stdin); print(os.path.basename(d.get('tool_input',{}).get('file_path','')))" 2>/dev/null)
fi

CWD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)

mkdir -p /tmp/maxwell_claude
rm -f "/tmp/maxwell_claude/$SESSION.json" 2>/dev/null
echo "{\"tool\":\"$TOOL\",\"cmd\":\"$CMD\",\"cwd\":\"$CWD\",\"time\":$(date +%s),\"session\":\"$SESSION\"}" > "/tmp/maxwell_claude/$SESSION.json"
```

**~/.claude/maxwell-hook-clear.sh**
```bash
#!/bin/bash
INPUT=$(cat)
SESSION=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null)
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
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Bash"}]
      },
      {
        "matcher": "Edit",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Edit"}]
      },
      {
        "matcher": "Write",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Write"}]
      },
      {
        "matcher": "Read",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook.sh Read"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook-clear.sh"}]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "~/.claude/maxwell-hook-clear.sh"}]
      }
    ]
  }
}
```

## Auto-start on Login

```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.maxwell.popup.plist

# Enable
launchctl load ~/Library/LaunchAgents/com.maxwell.popup.plist

# Remove completely
rm ~/Library/LaunchAgents/com.maxwell.popup.plist
```
