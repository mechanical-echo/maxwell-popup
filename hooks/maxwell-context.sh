#!/bin/bash
# Fires on PreToolUse. Records the last tool/command a session attempted so the
# Notification hook can enrich the waiting bubble. This NEVER triggers a bubble
# by itself - it is context only. The waiting state comes from maxwell-notify.sh.
TOOL="$1" python3 -c '
import sys, json, os, time

tool = os.environ.get("TOOL", "")
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

sid = d.get("session_id", "unknown")
ti = d.get("tool_input", {}) or {}
if tool == "Bash":
    cmd = (ti.get("command", "") or "")[:60]
else:
    cmd = os.path.basename(ti.get("file_path", "") or "")

out = {"tool": tool, "cmd": cmd, "cwd": d.get("cwd", ""), "time": int(time.time())}
os.makedirs("/tmp/maxwell_claude_ctx", exist_ok=True)
with open("/tmp/maxwell_claude_ctx/%s.json" % sid, "w") as f:
    f.write(json.dumps(out))
'
