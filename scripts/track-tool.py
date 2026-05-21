#!/usr/bin/env python3
"""
Matrix PreToolUse hook — reads tool JSON from stdin, writes to dashboard state files.
Claude Code calls this before every tool execution.
"""
import sys, json, os, time
import fcntl

sid = (os.environ.get('MATRIX_SESSION_ID') or '').strip()
suffix = f'-{sid}' if sid else ''
STATE_FILE  = os.environ.get('MATRIX_STATE_FILE') or f'/tmp/matrix-state{suffix}.json'
EVENTS_FILE = os.environ.get('MATRIX_EVENTS_FILE') or f'/tmp/matrix-events{suffix}.jsonl'

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = data.get('tool_name', 'unknown')
inp  = data.get('tool_input', {})

def first_int(*values):
    for v in values:
        if isinstance(v, bool):
            continue
        if isinstance(v, int):
            return v
        if isinstance(v, float):
            return int(v)
        if isinstance(v, str) and v.isdigit():
            return int(v)
    return None

usage = data.get('usage', {}) if isinstance(data.get('usage'), dict) else {}
metrics = data.get('metrics', {}) if isinstance(data.get('metrics'), dict) else {}
cost = data.get('cost', {}) if isinstance(data.get('cost'), dict) else {}

prompt_tokens = first_int(
    usage.get('input_tokens'),
    usage.get('prompt_tokens'),
    usage.get('prompt_token_count'),
    metrics.get('input_tokens'),
)
completion_tokens = first_int(
    usage.get('output_tokens'),
    usage.get('completion_tokens'),
    usage.get('completion_token_count'),
    metrics.get('output_tokens'),
)
total_tokens = first_int(
    usage.get('total_tokens'),
    usage.get('total_token_count'),
    metrics.get('total_tokens'),
    (prompt_tokens + completion_tokens) if (prompt_tokens is not None and completion_tokens is not None) else None
)
cost_usd = cost.get('usd') if isinstance(cost.get('usd'), (int, float)) else None

# Best single-line description of what the tool is touching
target = (
    inp.get('file_path')                                              or
    inp.get('path')                                                   or
    (inp.get('command', '')[:80] if inp.get('command') else None)    or
    inp.get('url', '')[:80]                                           or
    inp.get('query', '')[:80]                                         or
    inp.get('prompt', '')[:60]                                        or
    ''
)
raw_input_blob = ''
try:
    raw_input_blob = json.dumps(inp, separators=(',', ':'), ensure_ascii=False)
except Exception:
    raw_input_blob = str(inp) if inp else ''

# Better fallback when provider token usage is unavailable:
# estimate from full tool_input payload size instead of the truncated target label.
estimated_tokens = None
if raw_input_blob:
    estimated_tokens = max(1, int(round(len(raw_input_blob) / 4)))
elif target:
    estimated_tokens = max(1, int(round(len(target) / 4)))

ts  = int(time.time())
iso = time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(ts))

# Append event
try:
    event = {'ts': ts, 'iso': iso, 'tool': tool, 'target': target}
    if sid:
        event['session_id'] = sid
    if prompt_tokens is not None:
        event['prompt_tokens'] = prompt_tokens
    if completion_tokens is not None:
        event['completion_tokens'] = completion_tokens
    if total_tokens is not None:
        event['total_tokens'] = total_tokens
    elif estimated_tokens is not None:
        event['estimated_tokens'] = estimated_tokens
    if cost_usd is not None:
        event['cost_usd'] = round(float(cost_usd), 6)

    with open(f"{EVENTS_FILE}.lock", 'w') as lockf:
        fcntl.flock(lockf.fileno(), fcntl.LOCK_EX)
        with open(EVENTS_FILE, 'a+') as f:
            f.write(json.dumps(event) + '\n')
            f.flush()
            f.seek(0)
            lines = f.readlines()
            if len(lines) > 500:
                f.seek(0)
                f.truncate()
                f.writelines(lines[-500:])
                f.flush()
except Exception:
    pass

# Update state
state = {'tool_calls': 0}
try:
    with open(f"{STATE_FILE}.lock", 'w') as lockf:
        fcntl.flock(lockf.fileno(), fcntl.LOCK_EX)
        try:
            with open(STATE_FILE) as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    state = loaded
        except Exception:
            state = {'tool_calls': 0}

        state['last_tool'] = {'name': tool, 'target': target, 'at': ts}
        state['tool_calls'] = state.get('tool_calls', 0) + 1
        state['status'] = 'active'
        state['gate_e_armed'] = os.path.exists('/tmp/matrix-ticket.flag')
        state['last_tokens'] = total_tokens
        if prompt_tokens is not None:
            state['prompt_tokens_total'] = state.get('prompt_tokens_total', 0) + prompt_tokens
        if completion_tokens is not None:
            state['completion_tokens_total'] = state.get('completion_tokens_total', 0) + completion_tokens
        if total_tokens is not None:
            state['tokens_total'] = state.get('tokens_total', 0) + total_tokens
        elif estimated_tokens is not None:
            state['tokens_estimated_total'] = state.get('tokens_estimated_total', 0) + estimated_tokens
        if cost_usd is not None:
            state['cost_usd_total'] = round(state.get('cost_usd_total', 0.0) + float(cost_usd), 6)

        tmp = f"{STATE_FILE}.tmp"
        with open(tmp, 'w') as f:
            json.dump(state, f)
        os.replace(tmp, STATE_FILE)
except Exception:
    pass
