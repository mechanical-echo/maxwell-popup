#!/bin/bash
# Fires on Claude Code's Notification event. Writes a "waiting" marker ONLY when
# Claude is actually blocked on a permission prompt. In auto/accept modes no
# permission prompt is shown, so no Notification fires and no marker is written.
# Capture the tmux session (if any) so remote Telegram accept/reject can target it.
TMUX_SESSION=""
if [ -n "$TMUX" ]; then
    TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
fi

TMUXS="$TMUX_SESSION" python3 -c '
import sys, json, os, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

ntype = d.get("notification_type", "")
msg = d.get("message", "")
low = msg.lower()
is_idle = "waiting for your input" in low or "waiting for your next" in low

# Only permission prompts count as "waiting for approval".
# idle_prompt / other types are handled elsewhere (done bubbles via Stop hook).
if ntype:
    if ntype != "permission_prompt":
        sys.exit(0)
elif is_idle:
    sys.exit(0)

sid = d.get("session_id", "unknown")
cwd = d.get("cwd", "")
out = {"session": sid, "cwd": cwd, "message": msg,
       "type": ntype or "permission_prompt", "time": int(time.time())}
tmux = os.environ.get("TMUXS", "")
if tmux:
    out["tmux"] = tmux

# Enrich with the last tool/command this session attempted (written by
# maxwell-context.sh on PreToolUse) so the bubble can show what is waiting.
try:
    ctx = json.load(open("/tmp/maxwell_claude_ctx/%s.json" % sid))
    if abs(int(time.time()) - int(ctx.get("time", 0))) <= 30:
        out["tool"] = ctx.get("tool", "")
        out["cmd"] = ctx.get("cmd", "")
        if not out["cwd"]:
            out["cwd"] = ctx.get("cwd", "")
except Exception:
    pass

os.makedirs("/tmp/maxwell_claude", exist_ok=True)
with open("/tmp/maxwell_claude/%s.json" % sid, "w") as f:
    f.write(json.dumps(out))
'
