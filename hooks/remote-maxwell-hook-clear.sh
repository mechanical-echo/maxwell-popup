#!/bin/bash
INPUT=$(cat)

# CONFIGURE THIS: your Mac's username and IP/hostname
LOCAL_MAC="your-username@your-mac-ip"

SESSION=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null)

# Remove from local Mac via SSH (runs in background to not block Claude)
(ssh -o ConnectTimeout=2 -o BatchMode=yes "$LOCAL_MAC" "rm -f /tmp/maxwell_claude/$SESSION.json" 2>/dev/null &)
