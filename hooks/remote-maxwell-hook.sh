#!/bin/bash
TOOL="$1"
INPUT=$(cat)

# CONFIGURE THIS: your Mac's username and IP/hostname
LOCAL_MAC="your-username@your-mac-ip"

SESSION=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null)

if [ "$TOOL" = "Bash" ]; then
    CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command','')[:30])" 2>/dev/null)
else
    CMD=$(echo "$INPUT" | python3 -c "import sys,json,os; d=json.load(sys.stdin); print(os.path.basename(d.get('tool_input',{}).get('file_path','')))" 2>/dev/null)
fi

CWD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
TIME=$(date +%s)

# Send to local Mac via SSH (runs in background to not block Claude)
(ssh -o ConnectTimeout=2 -o BatchMode=yes "$LOCAL_MAC" "mkdir -p /tmp/maxwell_claude && echo '{\"tool\":\"$TOOL\",\"cmd\":\"$CMD\",\"cwd\":\"$CWD\",\"time\":$TIME,\"session\":\"$SESSION\",\"remote\":true}' > /tmp/maxwell_claude/$SESSION.json" 2>/dev/null &)
