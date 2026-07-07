#!/bin/bash
# Fires on Stop (Claude finished a turn and is now idle). Clears any waiting
# state and records a "done" marker (with the last user prompt, for the bubble).
python3 -c '
import sys, json, os, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

sid = d.get("session_id", "unknown")
cwd = d.get("cwd", "")

for p in ("/tmp/maxwell_claude/%s.json" % sid,
          "/tmp/maxwell_claude_ctx/%s.json" % sid):
    try:
        os.remove(p)
    except OSError:
        pass

prompt = ""
tpath = d.get("transcript_path", "")
try:
    if tpath and os.path.exists(tpath):
        with open(tpath) as f:
            lines = [l for l in f if l.strip()]
        for line in reversed(lines):
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") != "user":
                continue
            c = (e.get("message", {}) or {}).get("content", "")
            if isinstance(c, list):
                c = " ".join(part.get("text", "") for part in c
                             if isinstance(part, dict) and part.get("type") == "text")
            if isinstance(c, str) and c.strip() and not c.strip().startswith("<"):
                prompt = c.strip().replace("\n", " ")
                break
except Exception:
    pass

out = {"session": sid, "cwd": cwd, "prompt": prompt, "time": int(time.time())}
os.makedirs("/tmp/maxwell_claude_done", exist_ok=True)
with open("/tmp/maxwell_claude_done/%s.json" % sid, "w") as f:
    f.write(json.dumps(out))
'
