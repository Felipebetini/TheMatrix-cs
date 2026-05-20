#!/usr/bin/env python3
"""
Matrix PreToolUse hook — reads tool JSON from stdin, writes to dashboard state files.
Claude Code calls this before every tool execution.
"""
import sys, json, os, time

STATE_FILE  = '/tmp/matrix-state.json'
EVENTS_FILE = '/tmp/matrix-events.jsonl'

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = data.get('tool_name', 'unknown')
inp  = data.get('tool_input', {})

target = (
    inp.get('file_path')                                              or
    inp.get('path')                                                   or
    (inp.get('command', '')[:80] if inp.get('command') else None)    or
    inp.get('url', '')[:80]                                           or
    inp.get('query', '')[:80]                                         or
    inp.get('prompt', '')[:60]                                        or
    ''
)

ts  = int(time.time())
iso = time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(ts))

try:
    with open(EVENTS_FILE, 'a') as f:
        f.write(json.dumps({'ts': ts, 'iso': iso, 'tool': tool, 'target': target}) + '\n')

    with open(EVENTS_FILE) as f:
        lines = f.readlines()
    if len(lines) > 500:
        with open(EVENTS_FILE, 'w') as f:
            f.writelines(lines[-500:])
except Exception:
    pass

try:
    with open(STATE_FILE) as f:
        state = json.load(f)
except Exception:
    state = {'tool_calls': 0}

state['last_tool']    = {'name': tool, 'target': target, 'at': ts}
state['tool_calls']   = state.get('tool_calls', 0) + 1
state['status']       = 'active'
state['gate_e_armed'] = os.path.exists('/tmp/matrix-ticket.flag')

try:
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)
except Exception:
    pass
