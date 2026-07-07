#!/bin/bash
# Clears "waiting" state. Runs on:
#   PostToolUse      -> "tool"   (a tool was approved and ran)
#   UserPromptSubmit -> "prompt" (user typed something / answered)
#   SessionEnd       -> "end"    (session gone)
EVENT="$1" python3 -c '
import sys, json, os

event = os.environ.get("EVENT", "")
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sid = d.get("session_id", "unknown")

def rm(p):
    try:
        os.remove(p)
    except OSError:
        pass

rm("/tmp/maxwell_claude/%s.json" % sid)
if event in ("prompt", "end"):
    rm("/tmp/maxwell_claude_done/%s.json" % sid)
if event == "end":
    rm("/tmp/maxwell_claude_ctx/%s.json" % sid)
'
